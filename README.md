# This repository was merged into [Iguana](https://github.com/openSUSE/iguana) and obsoleted.

## dracut-iguana
## dracut module to include container runtime in initrd

_part of [Iguana installer research project](https://github.com/aaannz/iguana)._

Unstable software, use at your own risk.

## How to test

1) have an existing VM. Do not use your own machine!
2) install `dracut-iguana` package from [OBS](https://build.opensuse.org/package/show/home:oholecek/dracut-iguana)
3) call `dracut --verbose --force --no-hostonly --no-hostonly-cmdline --no-hostonly-default-device --no-hostonly-i18n --reproducible iguana-initrd $kernel_version`

  This will generate `iguana-initrd` file in your current directory.

4) Use new VM and boot directly to kernel and `iguana-initrd` created in previous steps.
5) To test with dinstaller, use `rd.iguana.control_url=https://raw.githubusercontent.com/aaannz/iguana-workflow/main/examples/d-installer.yaml rd.iguana.debug=1` as kernel command line

### Submit to OBS

[osc](https://openbuildservice.org/help/manuals/obs-user-guide/art.obs.bg.html#sec.obsbg.req) tool is required for submitting to the [OBS project](https://build.opensuse.org/package/show/home:oholecek/iguana-workflow)

1) checkout package to your project space

    `osc bco home:oholecek dracut-iguana`

2) from withing checked out project update cargo services

    `osc service ra`

2) remove old source tarballs
3) add new and remove old files

    `osc ar`

4) submit changes to your package

    `osc ci`

5) after tests create submit request

    `osc sr home:oholecek dracut-iguana`
