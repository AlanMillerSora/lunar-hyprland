// ════════════════════════════════════════════════════════════════
//  lunar-statsd — телеметрия для бара Lunar Eclipse.
//
//  Один долгоживущий процесс: читает /proc и hwmon НАПРЯМУЮ (без
//  форков hyprctl/jq/awk/date/nvidia-smi) и печатает строку
//  key=value, разделённую 0x1f, раз в interval секунд.
//
//  Заменяет горячий путь eclipse-status.sh для бара: CPU, RAM, сеть,
//  GPU, Game Mode, запись. Раскладка сюда НЕ входит — её бар берёт
//  событиями Hyprland (activelayout), поэтому kb/kbdev отсутствуют.
//
//  Сборка: см. lunar-statsd.sh (gcc -O2).
//  Ключи: --interval N (по умолчанию 1), --once (один замер и выход).
//
//  Память: без per-tick аллокаций, все буферы фиксированные.
// ════════════════════════════════════════════════════════════════

#define _GNU_SOURCE
#include <dirent.h>
#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#define DELIM "\x1f"   // ASCII unit separator, как в eclipse-status.sh

static volatile sig_atomic_t g_stop = 0;
static void on_sig(int s) { (void)s; g_stop = 1; }

// ── пути, зависящие от окружения (заполняются один раз) ──
static char g_gm_path[512];
static char g_governor[256];

// ── NVML через dlopen: без зависимости на этапе сборки ──
typedef struct { unsigned int gpu; unsigned int memory; } nvmlUtil_t;
typedef void *nvmlDevice_t;
static void *g_nvml;
static int (*p_init)(void);
static int (*p_shutdown)(void);
static int (*p_handle)(unsigned int, nvmlDevice_t *);
static int (*p_util)(nvmlDevice_t, nvmlUtil_t *);
static int (*p_temp)(nvmlDevice_t, int, unsigned int *);
static nvmlDevice_t g_gpu;
static int g_nvml_ok = 0;

static void nvml_open(void) {
    g_nvml = dlopen("libnvidia-ml.so.1", RTLD_LAZY);
    if (!g_nvml) return;
    p_init = (int (*)(void))dlsym(g_nvml, "nvmlInit_v2");
    if (!p_init) p_init = (int (*)(void))dlsym(g_nvml, "nvmlInit");
    p_shutdown = (int (*)(void))dlsym(g_nvml, "nvmlShutdown");
    p_handle = (int (*)(unsigned int, nvmlDevice_t *))dlsym(g_nvml, "nvmlDeviceGetHandleByIndex_v2");
    if (!p_handle) p_handle = (int (*)(unsigned int, nvmlDevice_t *))dlsym(g_nvml, "nvmlDeviceGetHandleByIndex");
    p_util = (int (*)(nvmlDevice_t, nvmlUtil_t *))dlsym(g_nvml, "nvmlDeviceGetUtilizationRates");
    p_temp = (int (*)(nvmlDevice_t, int, unsigned int *))dlsym(g_nvml, "nvmlDeviceGetTemperature");
    if (!p_init || !p_handle || !p_util) return;
    if (p_init() != 0) return;
    if (p_handle(0, &g_gpu) != 0) {
        if (p_shutdown) p_shutdown();
        return;
    }
    g_nvml_ok = 1;
}

// ── чтение первой строки файла ──
static int read_line(const char *path, char *buf, size_t n) {
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    if (!fgets(buf, (int)n, f)) { fclose(f); return -1; }
    fclose(f);
    buf[strcspn(buf, "\n")] = 0;
    return 0;
}

// ── CPU %: дельта busy/total между тиками ──
static unsigned long long g_prev_idle, g_prev_total;
static int g_cpu_ready = 0;
static int cpu_pct(void) {
    FILE *f = fopen("/proc/stat", "r");
    if (!f) return 0;
    char line[256];
    if (!fgets(line, sizeof line, f)) { fclose(f); return 0; }
    fclose(f);
    unsigned long long u, n, s, i, w = 0, irq = 0, soft = 0, steal = 0;
    int got = sscanf(line, "cpu %llu %llu %llu %llu %llu %llu %llu %llu",
                     &u, &n, &s, &i, &w, &irq, &soft, &steal);
    if (got < 4) return 0;
    unsigned long long idle = i + w;
    unsigned long long total = u + n + s + idle + irq + soft + steal;
    if (!g_cpu_ready) {
        g_prev_idle = idle; g_prev_total = total; g_cpu_ready = 1; return 0;
    }
    unsigned long long dt = total - g_prev_total;
    unsigned long long di = idle - g_prev_idle;
    g_prev_idle = idle; g_prev_total = total;
    if (dt == 0) return 0;
    long v = (long)(100ULL * (dt - di) / dt);
    if (v < 0) v = 0;
    if (v > 100) v = 100;
    return (int)v;
}

// ── RAM: процент занятости и всего МБ ──
static void mem_info(int *pct, unsigned long long *mb) {
    *pct = 0; *mb = 0;
    FILE *f = fopen("/proc/meminfo", "r");
    if (!f) return;
    char line[256];
    unsigned long long total = 0, avail = 0;
    while (fgets(line, sizeof line, f)) {
        if (sscanf(line, "MemTotal: %llu", &total) == 1) continue;
        if (sscanf(line, "MemAvailable: %llu", &avail) == 1) break;
    }
    fclose(f);
    if (total > 0) {
        *mb = total / 1024;
        long p = (long)((total - avail) * 100 / total);
        if (p < 0) p = 0;
        if (p > 100) p = 100;
        *pct = (int)p;
    }
}

// ── сеть: сырые байты rx/tx (скорость считает QML по дельте) ──
static void net_raw(unsigned long long *rx, unsigned long long *tx) {
    *rx = 0; *tx = 0;
    FILE *f = fopen("/proc/net/dev", "r");
    if (!f) return;
    char line[256];
    if (!fgets(line, sizeof line, f)) { fclose(f); return; }
    if (!fgets(line, sizeof line, f)) { fclose(f); return; }
    while (fgets(line, sizeof line, f)) {
        char *colon = strchr(line, ':');
        if (!colon) continue;
        char *p = line;
        while (*p == ' ' || *p == '\t') p++;
        char ifname[64];
        size_t len = (size_t)(colon - p);
        if (len >= sizeof ifname) len = sizeof ifname - 1;
        memcpy(ifname, p, len);
        ifname[len] = 0;
        if (strcmp(ifname, "lo") == 0) continue;
        unsigned long long r, a, b, c, d, e, g, h, t;
        if (sscanf(colon + 1, " %llu %llu %llu %llu %llu %llu %llu %llu %llu",
                   &r, &a, &b, &c, &d, &e, &g, &h, &t) == 9) {
            *rx += r;
            *tx += t;   // 9-е поле — байты передано
        }
    }
    fclose(f);
}

// ── вид подключения: eth | wifi:0 | off ──
static const char *net_kind(void) {
    char ifname[64] = "";
    FILE *f = fopen("/proc/net/route", "r");
    if (f) {
        char line[256];
        if (fgets(line, sizeof line, f)) {
            while (fgets(line, sizeof line, f)) {
                char name[64]; unsigned long dest = 1, gw; unsigned flags;
                if (sscanf(line, "%63s %lx %lx %x", name, &dest, &gw, &flags) == 4) {
                    if (dest == 0) { snprintf(ifname, sizeof ifname, "%s", name); break; }
                }
            }
        }
        fclose(f);
    }
    if (ifname[0]) {
        char p[160];
        struct stat st;
        snprintf(p, sizeof p, "/sys/class/net/%s/wireless", ifname);
        if (stat(p, &st) == 0 && S_ISDIR(st.st_mode)) return "wifi:0";
        return "eth";
    }
    return "off";
}

// ── температура CPU (k10temp/zenpower/coretemp) ──
static int cpu_temp(void) {
    int t = -1;
    DIR *d = opendir("/sys/class/hwmon");
    if (!d) return -1;
    struct dirent *e;
    while ((e = readdir(d)) != NULL) {
        if (e->d_name[0] == '.') continue;
        char p[320], name[64];
        snprintf(p, sizeof p, "/sys/class/hwmon/%s/name", e->d_name);
        if (read_line(p, name, sizeof name) != 0) continue;
        if (strcmp(name, "k10temp") == 0 || strcmp(name, "zenpower") == 0 ||
            strcmp(name, "coretemp") == 0) {
            snprintf(p, sizeof p, "/sys/class/hwmon/%s/temp1_input", e->d_name);
            FILE *f = fopen(p, "r");
            if (!f) continue;
            long v = 0;
            if (fscanf(f, "%ld", &v) == 1) t = (int)(v / 1000);
            fclose(f);
            break;
        }
    }
    closedir(d);
    return t;
}

// ── AMD GPU из sysfs (фолбэк, если NVML недоступен) ──
static void amdgpu(int *load, int *temp) {
    *load = -1; *temp = -1;
    DIR *d = opendir("/sys/class/drm");
    if (d) {
        struct dirent *e;
        while ((e = readdir(d)) != NULL) {
            if (strncmp(e->d_name, "card", 4) != 0 || strchr(e->d_name, '-')) continue;
            char p[320];
            snprintf(p, sizeof p, "/sys/class/drm/%s/device/gpu_busy_percent", e->d_name);
            char b[32];
            if (read_line(p, b, sizeof b) == 0) { *load = atoi(b); break; }
        }
        closedir(d);
    }
    DIR *h = opendir("/sys/class/hwmon");
    if (h) {
        struct dirent *e;
        while ((e = readdir(h)) != NULL) {
            if (e->d_name[0] == '.') continue;
            char p[320], name[64];
            snprintf(p, sizeof p, "/sys/class/hwmon/%s/name", e->d_name);
            if (read_line(p, name, sizeof name) != 0 || strcmp(name, "amdgpu") != 0)
                continue;
            snprintf(p, sizeof p, "/sys/class/hwmon/%s/temp1_input", e->d_name);
            FILE *f = fopen(p, "r");
            if (f) { long v = 0; if (fscanf(f, "%ld", &v) == 1) *temp = (int)(v / 1000); fclose(f); }
            break;
        }
        closedir(h);
    }
}

// ── идёт ли запись (our wf-recorder) ──
static int recording(void) {
    const char *rt = getenv("XDG_RUNTIME_DIR");
    char pidpath[512];
    snprintf(pidpath, sizeof pidpath, "%s/lunar-record.pid", rt ? rt : "/tmp");
    FILE *f = fopen(pidpath, "r");
    if (f) {
        long pid = 0;
        if (fscanf(f, "%ld", &pid) == 1 && pid > 0) {
            char cp[320], comm[32] = "";
            snprintf(cp, sizeof cp, "/proc/%ld/comm", pid);
            if (read_line(cp, comm, sizeof comm) == 0 && strcmp(comm, "wf-recorder") == 0) {
                fclose(f);
                return 1;
            }
        }
        fclose(f);
    }
    // фолбэк: ищу wf-recorder, пишущий в наш каталог ~/Videos/lunar-
    // скан всего /proc дорогой — делаю его не чаще раза в 3 с и кэширую
    static time_t last_scan = 0;
    static int last_val = 0;
    time_t now = time(NULL);
    if (now - last_scan < 3)
        return last_val;
    last_scan = now;

    const char *home = getenv("HOME");
    char needle[512];
    snprintf(needle, sizeof needle, "%s/Videos/lunar-", home ? home : "/root");
    DIR *d = opendir("/proc");
    if (!d) return 0;
    struct dirent *e;
    int found = 0;
    while ((e = readdir(d)) != NULL) {
        if (e->d_name[0] < '0' || e->d_name[0] > '9') continue;
        char cp[320], comm[32] = "";
        snprintf(cp, sizeof cp, "/proc/%s/comm", e->d_name);
        if (read_line(cp, comm, sizeof comm) != 0 || strcmp(comm, "wf-recorder") != 0)
            continue;
        char cl[320];
        snprintf(cl, sizeof cl, "/proc/%s/cmdline", e->d_name);
        FILE *lf = fopen(cl, "rb");
        if (!lf) continue;
        char buf[4096];
        size_t rn = fread(buf, 1, sizeof buf - 1, lf);
        fclose(lf);
        buf[rn] = 0;
        for (size_t k = 0; k + 1 < rn; k++)
            if (buf[k] == 0) buf[k] = ' ';
        if (strstr(buf, needle)) { found = 1; break; }
    }
    closedir(d);
    last_val = found;
    return found;
}

static int read_int_file(const char *path, int def) {
    FILE *f = fopen(path, "r");
    if (!f) return def;
    long v;
    int ok = fscanf(f, "%ld", &v);
    fclose(f);
    return ok == 1 ? (int)v : def;
}

int main(int argc, char **argv) {
    int interval = 1, once = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--once") == 0) once = 1;
        else if (strcmp(argv[i], "--interval") == 0 && i + 1 < argc)
            interval = atoi(argv[++i]);
    }
    if (interval < 1) interval = 1;

    signal(SIGTERM, on_sig);
    signal(SIGINT, on_sig);
    signal(SIGPIPE, SIG_IGN);
    // умри вместе с родителем (Quickshell): иначе при рестарте шелла
    // (KillMode=process) остаётся висеть старый демон и плодятся дубли
    prctl(PR_SET_PDEATHSIG, SIGTERM);
    // если родитель умер раньше prctl — уходим сразу
    if (getppid() == 1) return 0;
    setvbuf(stdout, NULL, _IOLBF, 0);

    const char *cache = getenv("XDG_CACHE_HOME");
    char cbuf[256];
    if (cache && cache[0]) snprintf(cbuf, sizeof cbuf, "%s/lunar", cache);
    else {
        const char *home = getenv("HOME");
        snprintf(cbuf, sizeof cbuf, "%s/.cache/lunar", home ? home : "/tmp");
    }
    snprintf(g_gm_path, sizeof g_gm_path, "%s/gamemode", cbuf);
    snprintf(g_governor, sizeof g_governor,
             "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor");

    nvml_open();
    cpu_pct();   // прогрев базовой линии CPU

    while (!g_stop) {
        int cpu = cpu_pct();
        int ctemp = cpu_temp();
        int ram;
        unsigned long long rtot;
        mem_info(&ram, &rtot);
        unsigned long long rx, tx;
        net_raw(&rx, &tx);

        int gpu = -1, gput = -1;
        if (g_nvml_ok) {
            nvmlUtil_t u;
            unsigned int temp = 0;
            if (p_util(g_gpu, &u) == 0) gpu = (int)u.gpu;
            if (p_temp && p_temp(g_gpu, 0, &temp) == 0) gput = (int)temp;
        } else {
            amdgpu(&gpu, &gput);
        }

        int gm = read_int_file(g_gm_path, 0);
        int rec = recording();
        char pp[64] = "";
        read_line(g_governor, pp, sizeof pp);
        const char *net = net_kind();

        printf("net=%s" DELIM "cpu=%d" DELIM "ctemp=%d" DELIM "ram=%d"
               DELIM "rtot=%llu" DELIM "rx=%llu" DELIM "tx=%llu"
               DELIM "gpu=%d" DELIM "gput=%d" DELIM "gm=%d" DELIM "pp=%s"
               DELIM "rec=%d\n",
               net, cpu, ctemp, ram, rtot, rx, tx, gpu, gput, gm, pp, rec);
        fflush(stdout);
        // родитель (Quickshell) умер или пайп закрыт — выхожу, не зависаю
        // «потерянным» процессом даже если PDEATHSIG не успел сработать
        if (getppid() == 1 || ferror(stdout))
            break;

        if (once) break;

        struct timespec ts = { interval, 0 };
        nanosleep(&ts, NULL);
    }

    if (g_nvml_ok && p_shutdown) p_shutdown();
    if (g_nvml) dlclose(g_nvml);
    return 0;
}
