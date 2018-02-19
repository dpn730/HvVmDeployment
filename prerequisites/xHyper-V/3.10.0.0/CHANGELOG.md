# Change log for xHyper-V

## Unreleased

* Added the following resources:
  * MSFT_xVMHardDiskDrive to manage additional attached VHD/Xs.
  * MSFT_xVMScsiController to manage virtual machine SCSI controllers.
* MSFT_xVMSwitch:
  * Added parameter ot specify the Load Balancing Algorithm of a vSwitch with Switch Embedded Teaming (SET)

## 3.10.0.0

* MSFT_xVMHyperV:
  * Added support for configuring automatic snapshots

## 3.9.0.0

* MSFT_xVMHyperV:
  * Enable / disable dynamic memory for client and server SKUs in identical way.
  * Increased xVMHyperV StartupMemory and MinimumMemory limits from 17GB to 64GB.
  * EnableGuestService works on localized OS (language independent).
  * Adds missing Hyper-V-PowerShell feature in examples.
* Added the following resources:
  * MSFT_xVMProcessor to manage virtual machine processor options.
  * MSFT_xVMHost to managing Hyper-V host settings.
* MSFT_xVMSwitch:
  * Added support for Switch Embedded Teaming (SET) in Server 2016.
  * Fixed a bug where Get-TargetResource threw an error if a non External switch
 is used.
  * Updated unit tests to use template version 1.2.0.
  * Style fixes.
  * Added support for Localization.
* xHyper-V module:
  * Added vs code formatting rule settings.
  * Fix Markdown rule violations in Readme.md.
  * Added .MetaTestOptIn.json for Markdown common test to be included.
  * Added Appveyor badge for Dev branch in Readme.md and moved to Branches section.
  * Added missing properties for all resources in Readme.md.
  * Added and corrected missing / wrong DataTypes and Dsc attributes in Readme.md.
  * Updated Readme to match DscResources style.
  * Created change log and linked to it from Readme.
  * Removed version info from Readme.
  * Updated appveyor.yml to use Appveyor module.
  * Examples:
    * Removed code from Readme and linked to example files instead.
    * Moved code to new example files where there was only code in Readme.
  * Codecov:
    * Updated appveyor.yml to include codecov.
    * Added .codecov.yml.
    * Added codecov badges to Readme.
* MSFT_xVHD:
  * Support setting the disk type.
  * Added unit tests.
  * Added example Sample\_xVHD\_FixedVHD.ps1
  * Style fixes

## 3.8.0.0

* Fix bug in xVMDvdDrive with hardcoded VM Name.
* Corrected Markdown rule violations in Readme.md.

## 3.7.0.0

* Adding a new resource
  * MSFT_xVMNetworkAdapter: Attaches a new VM network adapter to the management
 OS or VM.

## 3.6.0.0

* xVHD: Updated incorrect property name MaximumSize in error message
* Fix Markdown rule violations in Readme.md identified by [markdownlint](https://github.com/mivok/markdownlint/blob/master/docs/RULES.md).
* Created standard Unit/Integration test folder structure.
* Moved unit tests into Unit test folder.
* Renamed the unit tests to meet standards.
* Added the following resources:
  * xVMDvdDrive to manage DVD drives attached to a Hyper-V virtual machine.

## 3.5.0.0

* Converted appveyor.yml to install Pester from PSGallery instead of from Chocolatey.
* MSFT_xVMHyperV: Fixed bug in Test-TargetResource throwing when a Vhd's ParentPath
 property was null.

## 3.4.0.0

* MSFT_xVMHyperV: Fixed bug causing Test-TargetResource to fail when VM had snapshots.
* MSFT_xVMHyperV: Adds localization support.
* MSFT_xVMSwitch: Fixes bug where virtual switches are duplicated when
 BandwidthReservationMode is not specified.

## 3.3.0.0

* xHyperV: Added SecureBoot parameter to enable control of the secure boot BIOS
 setting on generation 2 VMs.
  * Fixed drive letter when mounting VHD when calling resource xVhdFile. Fixes #20.
* MSFT_xVMHyperV: Changed the SwitchName parameter to string[] to support
 assigning multiple NICs to virtual machines.
* MSFT_xVMHyperV: Changed the MACAddress parameter to string[] to support
 assigning multiple MAC addresses to virtual machines.
* MSFT_xVMHyperV: Added enabling of Guest Service Interface.
* MSFT_xVMSwitch: Added the BandwidthReservationMode parameter which specifies
 how minimum bandwidth is to be configured on a virtual switch

## 3.2.0.0

* Added data type System.String to CheckSum parameter of Get/Set/Test-TargetResource
 functions and aligned indentation.
* Minor fixes

## 3.1.0.0

* xVMHyperV: Fixed bug in mof schema (Generation property had two types)
* xVhdFileDirectory: Fixed typo in type comparison
* Readme updates

## 3.0.0.0

* Decoupled VM generation from underlying VHD format in xVMHyperV resource.
  * __Breaking change:__ xVMHyperV resource: Generation property type changed
 from a String to an Integer.
  * The initial generation property was tied to the virtual disk format which was
 incorrect and has been rectified.
  * This change will only impact configurations that have previously explicitly
 specified the VM generation is either "vhd" or "vhdx".

## 2.4.0.0

* Fixed VM power state issue in xVMHyperV resource

## 2.3.0

* Fixed check for presence of param AllowManagementOS.

## 2.2.1

## 2.1

* Added logic to automatically adjust VM's startup memory when only minimum and
 maximum memory is specified in configuration
* Fixed the issue that a manually stopped VM cannot be brought back to running
 state with DSC

## 2.0

* Added xVhdFileDirectory Resource
* Allowed name to be specified with the extension in xVhd (e.g. the Vhd name could
 either be "sample" or "sample.vhd")
* When a VHD cannot be removed because it is already being used by another process,
 an error will be thrown.

## 1.0.0.0

* Initial release with the following resources
  * xVhd
  * xVMHyperV
  * xVMSwitch