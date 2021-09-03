luanet.load_assembly("System");
luanet.load_assembly("System.Windows.Forms");


local opacUrl = GetSetting("OPACURL");
local enableQueue = GetSetting("EnableQueue");
local queue = GetSetting("Queue");

local interfaceManager = nil;
local searchForm = {};
local browser = nil;
local ribbonPage = nil;

local searchOCLC = nil;
local searchISN = nil;
local searchTitle = nil;

searchForm.Form = nil;

local Clipboard = luanet.import_type("System.Windows.Forms.Clipboard");
local Process = luanet.import_type("System.Diagnostics.Process");
-- local Application = luanet.import_type("System.Windows.Forms.Application"); -- Not sure what this statement is for, it comes from Matt Calsada at Atlas

require "Atlas.AtlasHelpers"

function Init()
    -- Only support Loans at this time.  ReShare does not currently support articles.
    if GetFieldValue("Transaction", "RequestType") == "Loan" then
        LogDebug("ReShare Addon: Loan request type found, initializing Chromium search engine");
        interfaceManager = GetInterfaceManager();
        searchForm = interfaceManager:CreateForm("ReShare OPAC Search", "Script");
        
        -- A read only text box to display status information about your search
        --statusText = searchForm:CreateTextEdit("Status", "ReShare VuFind Search Status:");
        --statusText.ReadOnly = true;
        -- This method didn't work well, didn't see a way to format the control where it wasn't blocking off a large section to the left.
        
        browser = searchForm:CreateBrowser("ReShare OPAC Search", "ReShare OPAC Search", "ReShare OPAC Search", "Chromium");
        -- browser.TextVisible = false; -- if needed
        
        ribbonPage = searchForm:GetRibbonPage("ReShare OPAC Search");
        local importButton = ribbonPage:CreateButton("Push Request to ReShare", GetClientImage("Forward32"), "PushReShare", "Queue Handling");
        if enableQueue == true then
            importButton.BarButton.Enabled = true;
        else
            importButton.BarButton.Enabled = false;
        end
        
        -- This button is only for debugging purposes.  Removed for production
        -- local copyURLButton = ribbonPage:CreateButton("Copy URL", GetClientImage("Copy32"), "CopyURL", "URL Handling");
        -- copyURLButton.BarButton.Enabled = true;
        
        local openSystemBrowser = ribbonPage:CreateButton("Open in Browser", GetClientImage("OpenBrowser32"), "OpenSystemBrowser", "URL Handling");
        openSystemBrowser.BarButton.Enabled = true;

        searchOCLC = ribbonPage:CreateButton("Perform OCLC Number Search", GetClientImage("WorldCat32"), "DoSearchOCLC", "Search Options");
        searchISN = ribbonPage:CreateButton("Perform ISSN/ISBN Number Search", GetClientImage("Table32"), "DoSearchISN", "Search Options");
        searchTitle = ribbonPage:CreateButton("Perform Title/Author Search", GetClientImage("History32"), "DoSearchTitle", "Search Options");
        EnableSearchButtons();
        
        searchForm.Form:Show();
        -- browser:Show();
        DoSearch();
    end
end

function EnableSearchButtons()
    -- Inefficient, we're doing these same data lookups a few places.
    local oclcNumber = GetFieldValue("Transaction","ESPNumber");
    if oclcNumber == "" then
        searchOCLC.BarButton.Enabled = false;
    else
        searchOCLC.BarButton.Enabled = true;
    end
    
    local isnNumber = GetFieldValue("Transaction","ISSN");
    if isnNumber == "" then
        searchISN.BarButton.Enabled = false;
    else
        searchISN.BarButton.Enabled = true;
    end
    
    local searchLoanTitle = GetFieldValue("Transaction", "LoanTitle");
    local searchAuthor = GetFieldValue("Transaction","LoanAuthor");
    if searchLoanTitle == "" and searchAuthor == "" then
        searchTitle.BarButton.Enabled = false;
    else
        searchTitle.BarButton.Enabled = true;
    end
end

-- ReShare only applies to loans at this time.  If they do ever support articles, redo this function again, and fix Init()
--
-- Note:  The original VuFind search code did not properly UrlEncode the title, use the UrlEncoder in AtlasHelpers to safely perform this task.
function DoSearch()
    -- Modified from the original VuFind version.  The ReShare server addon performs the search in this order.  If records are found, return; otherwise continue
    -- to the next step.  If more than one record is found the next step will cancel trigger a rejection, so hopefully ReShare's shared catalog is properly deduped.
    -- 1.  If an OCLC number is present in the request, use it.
    -- 2.  If an ISSN is present in the request, use it.
    -- 3.  Finally, perform a search using the title, author, and publication year.
    
    local oclcStatus = DoSearchOCLC();
    if oclcStatus == true then
        return
    end

    local isnStatus = DoSearchISN();
    if isnStatus == true then
        return
    end

    DoSearchTitle(); -- returns true or false, but the return value is not needed here.
end

function DoSearchOCLC()
    local oclcNumber = GetFieldValue("Transaction","ESPNumber");
    if oclcNumber ~= "" then
        browser:Navigate(opacUrl .. "Search/Results?lookfor=" .. AtlasHelpers.UrlEncode(oclcNumber) .. "&type=oclc_num");
        LogDebug("ReShare Addon: OCLC Number found in request, calling " .. opacUrl .. "Search/Results?lookfor=" .. AtlasHelpers.UrlEncode(oclcNumber) .. "&type=oclc_num");
        searchForm.Form.Text = "ReShare Search - OCLC Number";
        return true;
    else
        return false;
    end
end

function DoSearchISN()
    local isnNumber = GetFieldValue("Transaction","ISSN"); -- This ILLiad field contains the ISBN OR ISSN, depending on what type of material is provided.
    if isnNumber ~= "" then
        -- This ISN search type is not a standard SOLR search index in VuFind, but is provided in ReShare as a combination of the isbn and issn indexes.
        browser:Navigate(opacUrl .. "Search/Results?lookfor=" .. AtlasHelpers.UrlEncode(isnNumber) .. "&type=ISN");
        LogDebug("ReShare Addon: ISxN Number found in request, calling " .. opacUrl .. "Search/Results?lookfor=" .. AtlasHelpers.UrlEncode(isnNumber) .. "&type=ISN");
        searchForm.Form.Text = "ReShare Search - ISxN Number";
        return true;
    else
        return false;
    end
end

function DoSearchTitle()
    local searchLoanTitle = GetFieldValue("Transaction", "LoanTitle");
    local searchAuthor = GetFieldValue("Transaction","LoanAuthor");
    local searchYear = GetFieldValue("Transaction","LoanDate");
    local foundOne = false;
    
    local searchString = opacUrl .. "Search/Results?join=AND"
    
    if searchLoanTitle ~= "" then
        searchString = searchString .. "&lookfor0%5B%5D=" .. AtlasHelpers.UrlEncode(searchLoanTitle) .. "&type0%5B%5D=title";
        foundOne = true;
    end
    if searchAuthor ~= "" then
        searchString = searchString .. "&lookfor0%5B%5D=" .. AtlasHelpers.UrlEncode(searchAuthor) .. "&type0%5B%5D=author";
        foundOne = true;
    end
    if searchYear ~= "" and #searchYear == 4 then -- Only do a search on a 4 digit year
        searchString = searchString .. "&lookfor0%5B%5D=" .. AtlasHelpers.UrlEncode(searchYear) .. "&type0%5B%5D=publishDate";
        -- Just a year means nothing, don't search JUST for a year.
    end
    
    if foundOne == false then
        LogDebug("ReShare Addon: No title or author found!");
        return false;
    end
    
    browser:Navigate(searchString);
    LogDebug("ReShare Addon: title and/or author found, calling " .. searchString);
    searchForm.Form.Text = "ReShare Search - Title/Author";
    return true;
end

-- This callback doesn't work on the Chrome version of the browser control.  There's no DOM heirarchy like in the IE version.  To get a
-- specific field or data element in the displayed page, you'll need to do JavaScript injection using
-- browser:ExecuteScript("document.getElementById('id')"); and parsing the resulting response.Result and response.Success message.
-- function IsRecordPage()
	-- local tabnav = browser:GetElementInFrame(nil, "tabnav");
	-- if tabnav == nil then
		-- return false;
	-- end
	-- return true;
-- end

function OpenSystemBrowser()
    local currentUrl = browser.WebBrowser.Address;
    
    if (currentUrl and currentUrl ~= "")then
		LogDebug("ReShare Addon: Opening Browser URL in default browser: " .. currentUrl);
		process = Process();
        process.StartInfo.FileName = currentUrl;
		process.StartInfo.UseShellExecute = true;
		process:Start();
	end
end


function PushReShare()
    local tn = GetFieldValue("Transaction", "TransactionNumber");
    LogDebug("ReShare Addon: Received a Push to ReShare Request for TN: " .. tn .. " for Queue: " .. queue);
    -- WARNING: Do not uncomment this line until the ILLiad Server addon is released and ready for use.
    -- ExecuteCommand("RouteToBorrowing", {tn, queue});
end

-- This function is not used in production, it's tied to the disabled Copy URL button in Init()
function CopyURL()
    Clipboard.Clear();
    Clipboard.SetText(browser.WebBrowser.Address);
    LogDebug("ReShare Addon: Copying URL " .. browser.WebBrowser.Address);
end
