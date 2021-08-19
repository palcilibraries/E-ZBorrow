# ReShare Client ILLiad Addon

### Version 0.4 - Pre-release
### Written by Meredith Foster <mfoster@wcupa.edu>
### Based on the VuFind addon by WFU ZSR

## Overview

This client addon will allow an ILLiad staff user to search the ReShare *VuFind* frontend for the request title.

While not active yet, the addon should work with the upcoming *Atlas Systems* Reshare server addon.

## Installation

Copy the **ReShareClient** directory to your *ILLiad* addon folder.  For more information, check out Atlas's [Installing Client Addons](https://atlas-sys.atlassian.net/wiki/spaces/ILLiadAddons/pages/3149384/Installing+Client+Addons) page.

Make sure you have the Atlas addon, which should be shipped with the *ILLiad* client, it is required.

Check the configuration in Manage Addons in the *ILLiad* client.  Make sure it is active.  The URL is pre-set to the *E-ZBorrow VuFind* instance.  Make sure EnableQueue is turned off, as it will not work until the *ILLiad* server addon is available.  Leave the Queue option alone for now.

## Technical Details

This addon is a modification of the *VuFind* client addon available in the [ILLiad Addon Directory](https://atlas-sys.atlassian.net/wiki/spaces/ILLiadAddons/pages/3149543/ILLiad+Addon+Directory).  Several modifications to the original *VuFind* code were done.

- The browser engine was changed to *Chromium*.  This should help reduce any display issues from the standard *Internet Explorer* browser engine.
- A Push to Queue button has been added to the *ILLiad* ribbon at the top of the request.  When the server side addon is released by *Atlas*, this button should push the request into the server side addon's queue, similar to using the Route button in the request in the *ILLiad* client.
- The ReShare tab will only show up for Loan requests, as *E-ZBorrow* is only available for loan requests at this time.
- An Open in Browser button has been added to the ribbon, this will open the *VuFind* search results in an external browser window (using your system's default browser).
- Fixed a bug in the original *VuFind* addon code that would not properly encode the title.  *VuFind* would usually accept these invalid search strings, but the URL would not work when copying the URL or opening the search in an external browser.
