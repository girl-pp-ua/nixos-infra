{ ... }:
{
  services.sshguard = {
    enable = true;
    blocktime = 600;
    services = [
      "sshd"
      "sshd-session"
    ];
  };
}
