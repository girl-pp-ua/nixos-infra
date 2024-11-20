{ ... }: {
  swapDevices = [{
    device = "/swapfile";
    size = 16 * 1024; # 16GB
  }];
}