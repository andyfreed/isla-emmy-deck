// Tiny Mach-O wrapper: exec the updater script next to this binary.
// Exists because notarization wants a real signed executable as the bundle main.
#include <mach-o/dyld.h>
#include <libgen.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(void) {
    char path[PATH_MAX];
    uint32_t size = sizeof(path);
    if (_NSGetExecutablePath(path, &size) != 0) return 1;
    char real[PATH_MAX];
    if (!realpath(path, real)) return 1;
    char *dir = dirname(real);
    char script[PATH_MAX];
    snprintf(script, sizeof(script), "%s/../Resources/launch.sh", dir);
    execl("/bin/bash", "bash", script, (char *)NULL);
    return 1;
}
