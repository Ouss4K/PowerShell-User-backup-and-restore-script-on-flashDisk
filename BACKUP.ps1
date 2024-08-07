$ErrorActionPreference = 'silentlycontinue'
$user = $env:UserName
$actualPc = $env:computername
$driveLetter = Read-Host -Prompt 'Enter the drive letter for backup (e.D,B,E,Z:)'

If(Get-Volume -DriveLetter $driveLetter){
    $continue = $true
    Write-Host 'External backup hard drive connected.' -ForegroundColor Green
    $pc = Read-Host 'Please confirm the name of the replaced PC.'
    While(($Null -eq $pc) -or ($pc -eq '')){
        $pc = Read-Host -Prompt 'Please confirm the name of the replaced PC.'
    }
    If($actualPc -eq $pc){
        $continue = $true
        Write-Host 'Calculating the amount of data to be backed up...' -ForegroundColor Yellow

        $dataC = "{0:N2} " -f ((@(
        (Get-ChildItem C:\Users\$user\Desktop -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        (Get-ChildItem C:\Users\$user\Documents -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        #(Get-ChildItem C:\Users\$user\Downloads -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        #(Get-ChildItem C:\Users\$user\Favorites -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        (Get-ChildItem C:\Users\$user\Pictures -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        #(Get-ChildItem C:\Users\$user\Videos -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        (Get-ChildItem C:\Users\$user\AppData\Roaming\Microsoft\Signatures -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        (Get-ChildItem C:\Users\$user\AppData\Roaming\Microsoft\Templates -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        #(Get-ChildItem C:\Users\$user\AppData\Local\Microsoft\OneNote -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        (Get-ChildItem C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\Default -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        (Get-ChildItem C:\Users\$user\AppData\Local\Google\Chrome\User Data\Default -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        #(Get-ChildItem C:\Users\$user\AppData\Local\Packages\Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe\LocalState -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        ) | Measure-Object -Sum).Sum / 1Gb)
        Write-Host "Données C: $dataC Go" -ForegroundColor Green
		
    }else{

        <#$pathD = '$driveLetter\$pc'
        $testPathD = Test-Path -Path $pathD
        $msg = 'Nom de pc inexistant, veuillez réessayer'
        do {
            $response = Read-Host -Prompt $msg
            if ($response -ne $testPathD) {
                $msg = 'Nom de pc inexistant, veuillez réessayer'
            }
        } until ($testPathD)#>
        $contine = $true

    }
}else{
    $continue = $false
    Write-Host 'Please plug in your external backup hard drive.' -ForegroundColor Red
}

while ($continue){
  Read-Host 'Press ENTER to continue...'
  Write-Host '---------------------- MENU -----------------------'
  Write-Host '1.Copy Only Data As OneDrive' -ForegroundColor Green
  Write-Host '2 Copy Bookmark Chrome,edge,signatures ' -ForegroundColor Green
  Write-Host '3.Copy Full Chrome,Mozilla,Edge,Signatures,OneNote ' -ForegroundColor Green  
  Write-Host '4.Copy Liste Printers' -ForegroundColor Cyan
  Write-Host '5.Copy Liste Network Disk' -ForegroundColor Cyan
  Write-Host '6.copy OneNote Only' -ForegroundColor Yellow
  Write-Host '7.Copy Siganture Only' -ForegroundColor Yellow
  Write-Host '8.Copy mozila Only' -ForegroundColor Yellow
  Write-Host '9.Backup Data' -ForegroundColor Red
  Write-Host '10.Check list' -ForegroundColor Blue
  Write-Host '11.exit'
  Write-Host '----------------------------------------------------'
  $choix = Read-Host 'Your choice'
  switch ($choix){
    1
    {

        $msg = "Do you confirm that you want to back up the data? [Y/N]"
        do {
            $response = Read-Host -Prompt $msg
            if ($response -eq 'y') {

                $msg = "Do you confirm that the name of the replaced PC is $pc ? [Y/N]"
                do {
                    $response = Read-Host -Prompt $msg
                    if ($response -eq 'y') {

                        $desktop = "C:\Users\$user\Desktop"
                        $documents = "C:\Users\$user\Documents"
                        #$downloads = "C:\Users\$user\Downloads"
                        $pictures = "C:\Users\$user\Pictures"
                        $favorites = "C:\Users\$user\Favorites"
                        

                        $destinationDesktop = "$$pc\Desktop"
                        $destinationDocuments = "$$pc\Documents"
                        #$destinationDownloads = "$driveLetter\$pc\Downloads"
                        $destinationPictures = "$$pc\Pictures"
                        $destinationFavorites = "$pc\Favorites"
                        

                        robocopy $desktop $destinationDesktop /S /R:5 /MT:4
                        robocopy $documents $destinationDocuments /S /R:5 /MT:4
                        #robocopy $downloads $destinationDownloads /S /R:5 /MT:8
                        robocopy $pictures $destinationPictures /S /R:5 /MT:4
                        robocopy $favorites $destinationFavorites /S /R:5 /MT:4
                        

                        Write-Host 'Data backup completed successfully.' -ForegroundColor Green

                    }
                } until (($response -eq 'n') -or ($response -eq 'y'))

            }
        } until (($response -eq 'n') -or ($response -eq 'y'))

    }
	 2
    {

        $msg = "Do you confirm that you want to back up the data? [Y/N]"
        do {
            $response = Read-Host -Prompt $msg
            if ($response -eq 'y') {

                $msg = "Do you confirm that the name of the replaced PC is $pc ? [Y/N]"
                do {
                    $response = Read-Host -Prompt $msg
                    if ($response -eq 'y') {

                        $signatures = "C:\Users\$user\AppData\Roaming\Microsoft\Signatures"
                        $templates = "C:\Users\$user\AppData\Roaming\Microsoft\Templates" 
                        $edgebookmarks = "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\Default "
                        $chromebookmarks = "C:\Users\$user\AppData\Local\Google\Chrome\User Data\Default "
						#mozillabookmarks = "C:\Users\$user\AppData\Roaming\Mozilla\User Data\Default"

                        $destinationSignatures = "$pc\Signatures"
                        $destinationTemplates = "$pc\Templates"
                        $destinationEdge = "$pc\Edge"
                        $destinationChrome = "$pc\Chrome"
					    #$destinationMozilla ="$pc\Mozilla"

                        robocopy $signatures $destinationSignatures /S
                        robocopy $templates $destinationTemplates /S
                        robocopy $edgebookmarks $destinationEdge bookmarks
                        robocopy $chromebookmarks $destinationChrome bookmarks
					    #robocopy $Mozilla $destinationMozilla bookmarks

                        Write-Host 'Data backup completed successfully.' -ForegroundColor Green

                    }
                } until (($response -eq 'n') -or ($response -eq 'y'))

            }
        } until (($response -eq 'n') -or ($response -eq 'y'))

    }
	 3
    {

        $msg = "Do you confirm that you want to back up the data? [Y/N]"
        do {
            $response = Read-Host -Prompt $msg
            if ($response -eq 'y') {

                $msg = "Do you confirm that the name of the replaced PC is $pc ? [Y/N]"
                do {
                    $response = Read-Host -Prompt $msg
                    if ($response -eq 'y') {

                        $signatures = "C:\Users\$user\AppData\Roaming\Microsoft\Signatures"
                        $templates = "C:\Users\$user\AppData\Roaming\Microsoft\Templates"
                        $edgebookmarks = "C:\Users\$user\AppData\Local\Microsoft\Edge"
                        $chromebookmarks = "C:\Users\$user\AppData\Local\Google"
						$mozilla = "C:\Users\$user\AppData\Roaming\Mozilla"
						$onenote = "C:\Users\$user\AppData\Local\Microsoft\OneNote"

                        $destinationSignatures = "$pc\Signatures"
                        $destinationTemplates = "$pc\Templates"
                        $destinationEdge = "$pc\Edge"
                        $destinationChrome = "$pc\Chrome"
						$destinationMozilla ="$pc\Mozilla"
						$destinationonenote ="$pc\onenote"

                        robocopy $signatures $destinationSignatures /S
                        robocopy $templates $destinationTemplates /S
                        robocopy $edgebookmarks $destinationEdge /S /R:2 /MT:4
                        robocopy $chromebookmarks $destinationChrome /S /R:2 /MT:4
						robocopy $mozilla $destinationmozilla /S /R:2 /MT:4
						robocopy $onenote $destinationonenote /S /R:2 /MT:4

                        Write-Host 'Data backup completed successfully.' -ForegroundColor Green

                    }
                } until (($response -eq 'n') -or ($response -eq 'y'))

            }
        } until (($response -eq 'n') -or ($response -eq 'y'))

    }
	
    4
    {
        New-Item "$pc\Printers" -ItemType Directory
        Get-Printer | Format-Table | Out-File "$pc\Printers\installed_printers.txt"
		Write-Host 'Printer list exported successfully.' -ForegroundColor Green
    }
	5 {
            $networkDrives = Get-WmiObject -Query "SELECT * FROM Win32_NetworkConnection" | Select-Object LocalName, RemotePath
            New-Item "$pc\Disk" -ItemType Directory
			$filePath = "$pc\Disk\NetworkDisk.txt"
            $networkDrivesInfo = $networkDrives | ForEach-Object {
                "Lettre de lecteur : $($_.LocalName), Chemin rÃ©seau : $($_.RemotePath)"
            }
            $networkDrivesInfo | Out-File -FilePath $filePath -Encoding utf8
            Write-Host 'Paths of connected network drives saved successfully.' -ForegroundColor Green
        }
	
    6
    {
       $msg = "Do you confirm that you want to back up the data? [Y/N]"
        do {
            $response = Read-Host -Prompt $msg
            if ($response -eq 'y') {

                $msg = "Do you confirm that the name of the replaced PC is $pc ? [Y/N]"
                do {
                    $response = Read-Host -Prompt $msg
                    if ($response -eq 'y') {

                        
						$onenote = "C:\Users\$user\AppData\Local\Microsoft\OneNote"

                        
						$destinationonenote ="$pc\onenote"

                       
						robocopy $onenote $destinationonenote /S /R:2 /MT:4

                        Write-Host 'Data backup completed successfully.' -ForegroundColor Green

                    }
                } until (($response -eq 'n') -or ($response -eq 'y'))

            }
        } until (($response -eq 'n') -or ($response -eq 'y'))
    }
    7
    {
       $msg = "Do you confirm that you want to back up the data? [Y/N]"
        do {
            $response = Read-Host -Prompt $msg
            if ($response -eq 'y') {

                $msg = "Do you confirm that the name of the replaced PC is $pc ? [Y/N]"
                do {
                    $response = Read-Host -Prompt $msg
                    if ($response -eq 'y') {

                        $signatures = "C:\Users\$user\AppData\Roaming\Microsoft\Signatures"
                        

                        $destinationSignatures = "$pc\Signatures"
                        

                        robocopy $signatures $destinationSignatures /S
                        

                        Write-Host 'Data backup completed successfully.' -ForegroundColor Green

                    }
                } until (($response -eq 'n') -or ($response -eq 'y'))

            }
        } until (($response -eq 'n') -or ($response -eq 'y'))
    }
	
	8
    {

        $msg = "Do you confirm that you want to back up the data? [Y/N]"
        do {
            $response = Read-Host -Prompt $msg
            if ($response -eq 'y') {

                $msg = "Do you confirm that the name of the replaced PC is $pc ? [Y/N]"
                do {
                    $response = Read-Host -Prompt $msg
                    if ($response -eq 'y') {

                        
						$mozilla = "C:\Users\$user\AppData\Roaming\Mozilla"
						

                     
						$destinationMozilla ="$pc\Mozilla"
				

                      
						robocopy $mozilla $destinationmozilla /S /R:2 /MT:4
						

                        Write-Host 'Data backup completed successfully.' -ForegroundColor Green

                    }
                } until (($response -eq 'n') -or ($response -eq 'y'))

            }
        } until (($response -eq 'n') -or ($response -eq 'y'))

    }
	
    9
    {
    
        if(Test-Path -Path $pc){

            $msg = "Do you confirm that you want to restore the data? [Y/N]"
            do {
                $response = Read-Host -Prompt $msg
                if ($response -eq 'y') {

                    $msg = "Do you confirm that the name of the replaced PC is $pc ? [Y/N]"
                    do {
                        $response = Read-Host -Prompt $msg
                        if ($response -eq 'y') {

                            $sourceDesktop = "$pc\Desktop"
                            $sourceDocuments = "$pc\Documents"
                            #$sourceDownloads = "$pc\Downloads"
                            $sourcePictures = "$pc\Pictures"
                            #$sourceVideos = "$pc\Videos"
                            $sourceFavorites = "$pc\Favorites"
                            $sourceSignatures = "$pc\Signatures"
                            $sourceTemplates = "$driveLetter\$pc\Templates"
                            #$sourceOneNote = "$pc\OneNote"
                            $sourceEdge = "$pc\Edge"
                            $sourceChrome = "$pc\Chrome"
							$sourceMozilla = "$pc\Mozilla"
							$sourceonenote ="$pc\onenote"

                            $desktop = "C:\Users\$user\Desktop"
                            $documents = "C:\Users\$user\Documents"
                            #$downloads = "C:\Users\$user\Downloads"
                            $pictures = "C:\Users\$user\Pictures"
                            #$videos = "C:\Users\$user\Videos"
                            $favorites = "C:\Users\$user\Favorites"
                            $signatures = "C:\Users\$user\AppData\Roaming\Microsoft\Signatures"
                            $templates = "C:\Users\$user\AppData\Roaming\Microsoft\Templates"
                            #$onennote = "C:\Users\$user\AppData\Local\Microsoft\OneNote"
                            $edgebookmarks = "C:\Users\$user\AppData\Local\Microsoft\Edge"
                            $chromebookmarks = "C:\Users\$user\AppData\Local\Google"
							$mozillabookmarks = "C:\Users\$user\AppData\Roaming\Mozilla"
							$onenote = "C:\Users\$user\AppData\Local\Microsoft\OneNote"
							

                            robocopy $sourceDesktop $desktop /S /R:5 /MT:8
                            robocopy $sourceDocuments $documents /S /R:5 /MT:8
                            #robocopy $sourceDownloads $downloads /S /R:5 /MT:8
                            robocopy $sourcePictures $pictures /S /R:5 /MT:8
                            #robocopy $sourceVideos $videos /S /R:5 /MT:8
                            robocopy $sourceFavorites $favorites /S /R:5 /MT:8
                            robocopy $sourceSignatures $signatures /S /R:5 /MT:8
                            robocopy $sourceTemplates $templates /S /R:5 /MT:8
                            #robocopy $sourceOneNote $onennote /S /R:5 /MT:8
                            robocopy $sourceEdge $edgebookmarks /S /R:5 /MT:8
                            robocopy $sourceChrome $chromebookmarks /S /R:5 /MT:8
							robocopy $sourceMozilla $mozillabookmarks /S /R:5 /MT:8
							robocopy $sourceonenote $onenote /S /R:5 /MT:8
                            

                            Write-Host 'Data restoration completed successfully.' -ForegroundColor Green

                        }
                    } until (($response -eq 'n') -or ($response -eq 'y'))

                }
            } until (($response -eq 'n') -or ($response -eq 'y'))

        }else{

            Write-Host 'Unknown PC name.' -ForegroundColor Red
            $contine = $false

        }
    }
    10
    {
        Write-Host "To restore manually:

                    +Printers
                    +Taskbar shortcuts
                    +Edge/Chrome passwords
                    +Outlook archives
                    +'From'/'Bcc' tabs in Outlook
                    +Outlook signature settings"
    

    }
  11 {$continue = $false}
    default {Write-Host 'Invalid choice.' -ForegroundColor Red}
  }
}