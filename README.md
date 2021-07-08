# Ramiel
An open-source, multipurpose macOS utility for checkm8-vulnerable iOS/iPadOS devices.

Supported by macOS 10.13 -> 11.X. High Sierra has not been tested but should work fine. Anything lower is unsupported.

Ramiel is currently broken on M1 macs. Most tools for putting devices into PWNDFU mode are broken on M1 macs, an update will be pushed when this is fixed.

Ramiel will also not work on any pre-2012 macbooks/pros. As with M1 macs, most tools for putting devices into PWNDFU mode are broken for these old machines.


# FAQs
See [Ramiel.app](https://ramiel.app) for a list of FAQs.

# Usage
1. Navigate to the [releases page](https://github.com/MatthewPierson/Ramiel/releases) and download the latest build of Ramiel
2. Open the .dmg and move Ramiel.app to `/Applications`
3. Open Ramiel.app
4. Follow the setup prompts and allow Ramiel to download some tools
5. Connect a checkm8-compatible device in DFU mode
6. Have fun!

# Building
1. Install brew ```/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"```
2. Install cocoapods ```brew install cocoapods```
3. Install libirecovery ```brew install libirecovery```
4. Install libusb ```brew install libusb```
5. Install curl ```brew install curl```
6. Install libpng ```brew install libpng```
7. Install usbmuxd ```brew install usbmuxd```
8. Install git ```brew install git```
9. Clone the project ```git clone --recursive https://github.com/MatthewPierson/Ramiel```
10. Change directory into Ramiel ```cd Ramiel```
11. run ```pod install```
12. Open a new Finder window and go to /usr/local/Cellar/
13. Open Ramiel.xcworkspace and, in the top left corner, click Ramiel
14. Once in the new tab, select the Ramiel target  
15. ![tab](images/Project.png?raw=true)
16. Go down to ```Frameworks, Libraries, and Embedded Content``` 
17. ![libraries](images/dylibs.png?raw=true)
18. For any dylib that is greyed out, go back to that finder window and find the name of the tool, wheather that be libirecovery or curl
19. Select the dylib in xcode and hit the ```-``` button. 
20. ![select](images/selection.png?raw=true)
21. In finder, go to, for example ```/usr/local/Cellar/libirecovery/VERSION/lib/libirecovery-VERSION.dylib```, and drag that into the ```Frameworks, Libraries, and Embedded Content``` section.
22. Repeat this for all the things grayed out.
23. Finally go to Signing & Capabilities and change the Development team to yours, and you should now be able to compile!


# Issues
If you run into any bugs or issues with Ramiel, please [open an issue](https://github.com/MatthewPierson/Ramiel/issues) using the included templates. Please check for any similar issues that have already been opened before creating a new issue.

# Credits 
See [Ramiel.app](https://ramiel.app)'s credits section.
