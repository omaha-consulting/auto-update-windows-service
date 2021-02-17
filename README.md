# Automatically update a Windows Service with Google Omaha

This repository contains the source code for the [tutorial](https://omaha-consulting.com/auto-update-your-windows-service-with-google-omaha) with the above title. The tutorial shows how you can use Google's [open source Omaha framework](https://github.com/google/omaha) to update an exemplary Windows Service.

This repository is split into two parts:

1) `service` contains the source code for a simple Windows Service. It is a Visual Studio 2019 solution. The service's main functionality lies in [Service.cs](service/Service.cs). All the Service does is to periodically write its version to a log file, `C:\OmahaDemoService.log`.

2) `installer` is an [NSIS](https://nsis.sourceforge.io/Main_Page) project that can be used to package new versions of the service described in 1. The output is such that it can be uploaded to an Omaha-compatible update server. Specifically, `installer` takes the files produced by `service`'s build and produces a single .exe installer that supports silent installation via the `/S` flag.

To combine the two parts, first build `service` with Visual Studio. This produces files in `service\bin\Release`. Then use `makensis` to build `installer/Installer.nsi`. This takes the files from `service\bin\Release` and produces a self-contained executable. To update the "version" of the service thus produced, which is relevant for Omaha and shown in the service's log file, change `Service.cs` and `Installer.nsi`.
