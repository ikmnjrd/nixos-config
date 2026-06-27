{ ... }:

{
  services.flatpak = {
    enable = true;

    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];

    packages = [
      {
        appId = "com.brave.Browser";
        origin = "flathub";
      }
      {
        appId = "com.valvesoftware.Steam";
        origin = "flathub";
      }
    ];

    update = {
      onActivation = true;
      auto = {
        enable = true;
        onCalendar = "Mon,Thu *-*-* 03:00:00";
      };
    };
  };

  xdg.mime = {
    enable = true;
    defaultApplications = {
      "text/html" = [ "com.brave.Browser.desktop" ];
      "application/xhtml+xml" = [ "com.brave.Browser.desktop" ];
      "x-scheme-handler/http" = [ "com.brave.Browser.desktop" ];
      "x-scheme-handler/https" = [ "com.brave.Browser.desktop" ];
    };
  };
}
