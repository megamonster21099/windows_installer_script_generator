## A Flutter plugin for creating scripts for Inno Setup Compiler https://jrsoftware.org/isinfo.php

Currently tested on Windows only. Feel free to check on MacOS.

# Getting started

1. Download and install Inno Setup Compiler from https://jrsoftware.org/isdl.php#stable
2. Add a dev dependency in your `pubspec.yaml` file:
    ```yaml
    dev_dependencies:
      windows_installer_script_generator:
        git:
          url: https://github.com/megamonster21099/windows_installer_script_generator
    ```
3. Optionally, you can add a configurations in your `pubspec.yaml` file as follows:
   ```yaml
   windows_installer_script_generator_config:
      app_display_name: My project Name
      publisher: My Name
      script_output_dir: C:\Script_output_dir
      installer_output_dir: D:\Output_dir
      icon: C:\Workspace\your_project\windows_icon.ico
    ```
4. Run the following command to generate the script:
    ```bash
    dart run windows_installer_script_generator:make
    ```
5. Open the generated script with Inno Setup Compiler and compile it.
