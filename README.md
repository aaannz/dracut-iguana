# dracut-iguana
## dracut module to include container runtime in initrd

Part of Iguana installer research project. Use at your own risk.

## How to test

1) have an existing VM. Do not use your own machine!
2) install `dracut-iguana` package from [OBS](https://build.opensuse.org/package/show/home:oholecek/dracut-iguana)
3) call `dracut --verbose --force --no-hostonly --no-hostonly-cmdline --no-hostonly-default-device --no-hostonly-i18n --reproducible iguana-initrd $kernel_version`

  This will generate `iguana-initrd` file in your current directory.

4) Use new VM and boot directly to kernel and `iguana-initrd` created in previous steps.
5) To test with dinstaller, use `rd.iguana.containers=registry.opensuse.org/yast/head/containers/containers_tumbleweed/opensuse/dinstaller-all:latest rd.iguana.debug=1` as kernel command line