﻿#Requires -Modules Pester
#Requires -Modules Assert

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

Import-Module $here -Force

$WarningPreference = 'SilentlyContinue'
# $WarningPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$Path = '.\Test.xlsx'

Context 'input' {
    in $TestDrive {
        Describe 'parameters' {
            Context 'mandatory in sets' {
                it 'Path' {
                    (Get-Command Import-Excel).Parameters['Path'].Attributes.Mandatory | Should be $true
                }
                it 'WorksheetName' {
                    (Get-Command Import-Excel).Parameters['WorksheetName'].Attributes.Mandatory | Should be $true
                }
                it 'HeaderName' {
                    (Get-Command Import-Excel).Parameters['HeaderName'].Attributes.Mandatory | Should be $true
                }
                it 'NoHeader' {
                    (Get-Command Import-Excel).Parameters['NoHeader'].Attributes.Mandatory | Should be $true
                }
            }
            Context 'optional' {
                it 'TopRow' {
                    (Get-Command Import-Excel).Parameters['TopRow'].Attributes.Mandatory | Should be $false
                }
                it 'DataOnly' {
                    (Get-Command Import-Excel).Parameters['DataOnly'].Attributes.Mandatory | Should be $false
                }
            }
            Context 'illegal combinations' {
                it 'NoHeader combined with HeaderName' {
                    ''| Export-Excel -Path $Path -WorkSheetname Kiwi
                    {Import-Excel -Path $Path -WorksheetName Test -HeaderName A -NoHeader} | Should Throw 'Parameter set cannot be resolved'
                }
            }
        }
        Describe 'worksheet' {

            #region Create test file
            $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
            $Excel = New-Object OfficeOpenXml.ExcelPackage $Path
            $Excel | Add-WorkSheet -WorkSheetname Test
            $Excel.Save()
            $Excel.Dispose()
            #endregion

            it 'not found' {
                {Import-Excel -Path $Path -WorksheetName NotExisting} | Should Throw 'not found'
            }
            it 'empty' {               
                Import-Excel -Path $Path -WorksheetName Test -NoHeader | Should BeNullOrEmpty
            }
        }
    }
}

Context 'output' {
    in $TestDrive {
        Describe 'missing column header' {

            #region Create test file
            <#
                ----------------------------------------------
                |           A           B            C       |
                |1     First Name                 Address    |
                |2     Chuck         Norris       California |
                |3     Jean-Claude   Vandamme     Brussels   |
                ----------------------------------------------
            #>

            $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
            $Excel = New-Object OfficeOpenXml.ExcelPackage $Path
            $Worksheet = $Excel | Add-WorkSheet -WorkSheetname Test

            # Row, Column
            $Worksheet.Cells[1, 1].Value = 'First Name'
            $Worksheet.Cells[1, 3].Value = 'Address'
            $Worksheet.Cells[2, 1].Value = 'Chuck'
            $Worksheet.Cells[2, 2].Value = 'Norris'
            $Worksheet.Cells[2, 3].Value = 'California'
            $Worksheet.Cells[3, 1].Value = 'Jean-Claude'
            $Worksheet.Cells[3, 2].Value = 'Vandamme'
            $Worksheet.Cells[3, 3].Value = 'Brussels'

            $Excel.Save()
            $Excel.Dispose()
            #endregion

            it 'Default' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'First Name' = 'Chuck'
                        'Address'    = 'California'
                    }
                    [PSCustomObject]@{
                        'First Name' = 'Jean-Claude'
                        'Address'    = 'Brussels'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test 
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'Default and TopRow' {
                $ExpectedResult = [PSCustomObject]@{
                    'Chuck'      = 'Jean-Claude'
                    'Norris'     = 'Vandamme'
                    'California' = 'Brussels'
                }
                
                $Result = Import-Excel -Path $Path -WorksheetName Test -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
                
                Import-Excel -Path $Path -WorksheetName Test -TopRow 4 | Should BeNullOrEmpty
            }
            it 'Default and DataOnly' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'First Name' = 'Chuck'
                        'Address'    = 'California'
                    }
                    [PSCustomObject]@{
                        'First Name' = 'Jean-Claude'
                        'Address'    = 'Brussels'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -DataOnly
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'Default, DataOnly and TopRow' {
                $ExpectedResult = [PSCustomObject]@{
                    'Chuck'      = 'Jean-Claude'
                    'Norris'     = 'Vandamme'
                    'California' = 'Brussels'
                }

                $Result = Import-Excel -Path $Path -WorksheetName Test -DataOnly -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                Import-Excel -Path $Path -WorksheetName Test  -DataOnly -TopRow 4 | Should BeNullOrEmpty
                #{Import-Excel -Path $Path -WorksheetName Test -DataOnly -TopRow 4} | Should Throw 'No column headers found'
            }
            it 'NoHeader' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'P1' = 'First Name'
                        'P2' = $null
                        'P3' = 'Address'
                    }
                    [PSCustomObject]@{
                        'P1' = 'Chuck'
                        'P2' = 'Norris'
                        'P3' = 'California'
                    }
                    [PSCustomObject]@{
                        'P1' = 'Jean-Claude'
                        'P2' = 'Vandamme'
                        'P3' = 'Brussels'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -NoHeader
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'NoHeader and TopRow' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'P1' = 'Chuck'
                        'P2' = 'Norris'
                        'P3' = 'California'
                    }
                    [PSCustomObject]@{
                        'P1' = 'Jean-Claude'
                        'P2' = 'Vandamme'
                        'P3' = 'Brussels'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -NoHeader -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                Import-Excel -Path $Path -WorksheetName Test -NoHeader -TopRow 4 | Should BeNullOrEmpty
            }
            it 'NoHeader and DataOnly' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'P1' = 'First Name'
                        'P2' = $null
                        'P3' = 'Address'
                    }
                    [PSCustomObject]@{
                        'P1' = 'Chuck'
                        'P2' = 'Norris'
                        'P3' = 'California'
                    }
                    [PSCustomObject]@{
                        'P1' = 'Jean-Claude'
                        'P2' = 'Vandamme'
                        'P3' = 'Brussels'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -NoHeader -DataOnly
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'NoHeader, DataOnly and TopRow' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'P1' = 'Chuck'
                        'P2' = 'Norris'
                        'P3' = 'California'
                    }
                    [PSCustomObject]@{
                        'P1' = 'Jean-Claude'
                        'P2' = 'Vandamme'
                        'P3' = 'Brussels'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -NoHeader -DataOnly -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                Import-Excel -Path $Path -WorksheetName Test -NoHeader -DataOnly -TopRow 4 | Should BeNullOrEmpty
            }
            it 'HeaderName' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'FirstName'  = 'First Name'
                        'SecondName' = $null
                        'City'       = 'Address'
                        'Rating'     = $null
                    }
                    [PSCustomObject]@{
                        'FirstName'  = 'Chuck'
                        'SecondName' = 'Norris'
                        'City'       = 'California'
                        'Rating'     = $null
                    }
                    [PSCustomObject]@{
                        'FirstName'  = 'Jean-Claude'
                        'SecondName' = 'Vandamme'
                        'City'       = 'Brussels'
                        'Rating'     = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName FirstName, SecondName, City, Rating
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'FirstName'  = 'First Name'
                        'SecondName' = $null
                        'City'       = 'Address'
                        'Rating'     = $null
                        'Country'    = $null
                    }
                    [PSCustomObject]@{
                        'FirstName'  = 'Chuck'
                        'SecondName' = 'Norris'
                        'City'       = 'California'
                        'Rating'     = $null
                        'Country'    = $null
                    }
                    [PSCustomObject]@{
                        'FirstName'  = 'Jean-Claude'
                        'SecondName' = 'Vandamme'
                        'City'       = 'Brussels'
                        'Rating'     = $null
                        'Country'    = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName FirstName, SecondName, City, Rating, Country
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'HeaderName and TopRow' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'FirstName'  = 'Chuck'
                        'SecondName' = 'Norris'
                        'City'       = 'California'
                        'Rating'     = $null
                    }
                    [PSCustomObject]@{
                        'FirstName'  = 'Jean-Claude'
                        'SecondName' = 'Vandamme'
                        'City'       = 'Brussels'
                        'Rating'     = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName FirstName, SecondName, City, Rating -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'FirstName'  = 'Chuck'
                        'SecondName' = 'Norris'
                        'City'       = 'California'
                        'Rating'     = $null
                        'Country'    = $null
                    }
                    [PSCustomObject]@{
                        'FirstName'  = 'Jean-Claude'
                        'SecondName' = 'Vandamme'
                        'City'       = 'Brussels'
                        'Rating'     = $null
                        'Country'    = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName FirstName, SecondName, City, Rating, Country -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                Import-Excel -Path $Path -WorksheetName Test -HeaderName FirstName, SecondName, City, Rating, Country -TopRow 4 | Should BeNullOrEmpty
            }
            it 'HeaderName and DataOnly' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'FirstName'  = 'First Name'
                        'SecondName' = $null
                        'City'       = 'Address'
                        'Rating'     = $null
                    }
                    [PSCustomObject]@{
                        'FirstName'  = 'Chuck'
                        'SecondName' = 'Norris'
                        'City'       = 'California'
                        'Rating'     = $null
                    }
                    [PSCustomObject]@{
                        'FirstName'  = 'Jean-Claude'
                        'SecondName' = 'Vandamme'
                        'City'       = 'Brussels'
                        'Rating'     = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName FirstName, SecondName, City, Rating -DataOnly
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'FirstName'  = 'First Name'
                        'SecondName' = $null
                        'City'       = 'Address'
                        'Rating'     = $null
                        'Country'    = $null
                    }
                    [PSCustomObject]@{
                        'FirstName'  = 'Chuck'
                        'SecondName' = 'Norris'
                        'City'       = 'California'
                        'Rating'     = $null
                        'Country'    = $null
                    }
                    [PSCustomObject]@{
                        'FirstName'  = 'Jean-Claude'
                        'SecondName' = 'Vandamme'
                        'City'       = 'Brussels'
                        'Rating'     = $null
                        'Country'    = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName FirstName, SecondName, City, Rating, Country -DataOnly
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'HeaderName, DataOnly and TopRow' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'FirstName'  = 'Chuck'
                        'SecondName' = 'Norris'
                        'City'       = 'California'
                        'Rating'     = $null
                    }
                    [PSCustomObject]@{
                        'FirstName'  = 'Jean-Claude'
                        'SecondName' = 'Vandamme'
                        'City'       = 'Brussels'
                        'Rating'     = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName FirstName, SecondName, City, Rating -DataOnly -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'FirstName'  = 'Chuck'
                        'SecondName' = 'Norris'
                        'City'       = 'California'
                        'Rating'     = $null
                        'Country'    = $null
                    }
                    [PSCustomObject]@{
                        'FirstName'  = 'Jean-Claude'
                        'SecondName' = 'Vandamme'
                        'City'       = 'Brussels'
                        'Rating'     = $null
                        'Country'    = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName FirstName, SecondName, City, Rating, Country -DataOnly -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                Import-Excel -Path $Path -WorksheetName Test -HeaderName FirstName, SecondName, City, Rating, Country -DataOnly -TopRow 4 | Should BeNullOrEmpty
            }
        }
        Describe 'blank rows and columns' {

            #region Create test file
            <#
                ---------------------------------------------------------------------
                |           A            B            C          D         E        |
                |1     Movie name      Year           Rating               Genre    |
                |2     The Bodyguard   1992           9                    Thriller |
                |3     The Matrix      1999           8                    Sci-Fi   |
                |4                                                                  |
                |5     Skyfall         2012           9                    Thriller |
                ---------------------------------------------------------------------
            #>

            $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
            $Excel = New-Object OfficeOpenXml.ExcelPackage $Path
            $Worksheet = $Excel | Add-WorkSheet -WorkSheetname Test

            # Row, Column
            $Worksheet.Cells[1, 1].Value = 'Movie name'
            $Worksheet.Cells[1, 2].Value = 'Year'
            $Worksheet.Cells[1, 3].Value = 'Rating'
            $Worksheet.Cells[1, 5].Value = 'Genre'
            $Worksheet.Cells[2, 1].Value = 'The Bodyguard'
            $Worksheet.Cells[2, 2].Value = '1982'
            $Worksheet.Cells[2, 3].Value = '9'
            $Worksheet.Cells[2, 5].Value = 'Thriller'
            $Worksheet.Cells[3, 1].Value = 'The Matrix'
            $Worksheet.Cells[3, 2].Value = '1999'
            $Worksheet.Cells[3, 3].Value = '8'
            $Worksheet.Cells[3, 5].Value = 'Sci-Fi'
            $Worksheet.Cells[5, 1].Value = 'Skyfall'
            $Worksheet.Cells[5, 2].Value = '2012'
            $Worksheet.Cells[5, 3].Value = '9'
            $Worksheet.Cells[5, 5].Value = 'Thriller'

            $Excel.Save()
            $Excel.Dispose()
            #endregion

            it 'Default' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'Movie name' = 'The Bodyguard'
                        'Year'       = '1982'
                        'Rating'     = '9'
                        'Genre'      = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'Movie name' = 'The Matrix'
                        'Year'       = '1999'
                        'Rating'     = '8'
                        'Genre'      = 'Sci-Fi'
                    }
                    [PSCustomObject]@{
                        'Movie name' = $null
                        'Year'       = $null
                        'Rating'     = $null
                        'Genre'      = $null
                    }
                    [PSCustomObject]@{
                        'Movie name' = 'Skyfall'
                        'Year'       = '2012'
                        'Rating'     = '9'
                        'Genre'      = 'Thriller'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'Default and TopRow' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'The Bodyguard' = 'The Matrix'
                        '1982'          = '1999'
                        '9'             = '8'
                        'Thriller'      = 'Sci-Fi'
                    }
                    [PSCustomObject]@{
                        'The Bodyguard' = $null
                        '1982'          = $null
                        '9'             = $null
                        'Thriller'      = $null
                    }
                    [PSCustomObject]@{
                        'The Bodyguard' = 'Skyfall'
                        '1982'          = '2012'
                        '9'             = '9'
                        'Thriller'      = 'Thriller'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                {Import-Excel -Path $Path -WorksheetName Test -TopRow 4} | Should Throw 'No column headers found'
                Import-Excel -Path $Path -WorksheetName Test -TopRow 5 | Should BeNullOrEmpty
            }
            it 'Default and DataOnly' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'Movie name' = 'The Bodyguard'
                        'Year'       = '1982'
                        'Rating'     = '9'
                        'Genre'      = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'Movie name' = 'The Matrix'
                        'Year'       = '1999'
                        'Rating'     = '8'
                        'Genre'      = 'Sci-Fi'
                    }
                    [PSCustomObject]@{
                        'Movie name' = 'Skyfall'
                        'Year'       = '2012'
                        'Rating'     = '9'
                        'Genre'      = 'Thriller'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -DataOnly
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'Default, DataOnly and TopRow' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'The Bodyguard' = 'The Matrix'
                        '1982'          = '1999'
                        '9'             = '8'
                        'Thriller'      = 'Sci-Fi'
                    }
                    [PSCustomObject]@{
                        'The Bodyguard' = 'Skyfall'
                        '1982'          = '2012'
                        '9'             = '9'
                        'Thriller'      = 'Thriller'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -DataOnly -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
                
                {Import-Excel -Path $Path -WorksheetName Test -DataOnly -TopRow 4} | Should Throw 'No column headers found'

                Import-Excel -Path $Path -WorksheetName Test -DataOnly -TopRow 5 | Should BeNullOrEmpty
            }
            it 'HeaderName' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'MovieName' = 'Movie name'
                        'Year'       = 'Year'
                        'Rating'     = 'Rating'
                        'Genre'      = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Bodyguard'
                        'Year'       = '1982'
                        'Rating'     = '9'
                        'Genre'      = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Matrix'
                        'Year'       = '1999'
                        'Rating'     = '8'
                        'Genre'      = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = $null
                        'Year'       = $null
                        'Rating'     = $null
                        'Genre'      = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'Skyfall'
                        'Year'       = '2012'
                        'Rating'     = '9'
                        'Genre'      = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'MovieName' = 'Movie name'
                        'Year'       = 'Year'
                        'Rating'     = 'Rating'
                        'Genre'      = $null
                        'Country'    = 'Genre'
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Bodyguard'
                        'Year'       = '1982'
                        'Rating'     = '9'
                        'Genre'      = $null
                        'Country'    = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Matrix'
                        'Year'       = '1999'
                        'Rating'     = '8'
                        'Genre'      = $null
                        'Country'    = 'Sci-Fi'
                    }
                    [PSCustomObject]@{
                        'MovieName' = $null
                        'Year'       = $null
                        'Rating'     = $null
                        'Genre'      = $null
                        'Country'    = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'Skyfall'
                        'Year'       = '2012'
                        'Rating'     = '9'
                        'Genre'      = $null
                        'Country'    = 'Thriller'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre, Country
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'HeaderName and TopRow' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'MovieName' = 'The Bodyguard'
                        'Year'       = '1982'
                        'Rating'     = '9'
                        'Genre'      = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Matrix'
                        'Year'      = '1999'
                        'Rating'    = '8'
                        'Genre'     = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = $null
                        'Year'      = $null
                        'Rating'    = $null
                        'Genre'     = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'Skyfall'
                        'Year'      = '2012'
                        'Rating'    = '9'
                        'Genre'     = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'MovieName' = 'The Bodyguard'
                        'Year'      = '1982'
                        'Rating'    = '9'
                        'Genre'     = $null
                        'Country'   = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Matrix'
                        'Year'      = '1999'
                        'Rating'    = '8'
                        'Genre'     = $null
                        'Country'   = 'Sci-Fi'
                    }
                    [PSCustomObject]@{
                        'MovieName' = $null
                        'Year'      = $null
                        'Rating'    = $null
                        'Genre'     = $null
                        'Country'   = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'Skyfall'
                        'Year'      = '2012'
                        'Rating'    = '9'
                        'Genre'     = $null
                        'Country'   = 'Thriller'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre, Country -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
                
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'MovieName' = $null
                        'Year'      = $null
                        'Rating'    = $null
                        'Genre'     = $null
                        'Country'   = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'Skyfall'
                        'Year'      = '2012'
                        'Rating'    = '9'
                        'Genre'     = $null
                        'Country'   = 'Thriller'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre, Country -TopRow 4
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                $ExpectedResult = [PSCustomObject]@{
                    'MovieName' = 'Skyfall'
                    'Year'      = '2012'
                    'Rating'    = '9'
                    'Genre'     = $null
                    'Country'   = 'Thriller'
                }
                
                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre, Country  -TopRow 5
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre, Country -TopRow 6 | Should BeNullOrEmpty
            }
            it 'HeaderName and DataOnly' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'MovieName' = 'Movie name'
                        'Year'       = 'Year'
                        'Rating'     = 'Rating'
                        'Genre'      = 'Genre'
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Bodyguard'
                        'Year'       = '1982'
                        'Rating'     = '9'
                        'Genre'      = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Matrix'
                        'Year'       = '1999'
                        'Rating'     = '8'
                        'Genre'      = 'Sci-Fi'
                    }

                    [PSCustomObject]@{
                        'MovieName' = 'Skyfall'
                        'Year'       = '2012'
                        'Rating'     = '9'
                        'Genre'      = 'Thriller'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre -DataOnly
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'MovieName' = 'Movie name'
                        'Year'       = 'Year'
                        'Rating'     = 'Rating'
                        'Genre'      = 'Genre'
                        'Country'    = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Bodyguard'
                        'Year'       = '1982'
                        'Rating'     = '9'
                        'Genre'      = 'Thriller'
                        'Country'    = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Matrix'
                        'Year'       = '1999'
                        'Rating'     = '8'
                        'Genre'      = 'Sci-Fi'
                        'Country'    = $null
                    }

                    [PSCustomObject]@{
                        'MovieName' = 'Skyfall'
                        'Year'       = '2012'
                        'Rating'     = '9'
                        'Genre'      = 'Thriller'
                        'Country'    = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre, Country -DataOnly
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'HeaderName, DataOnly and TopRow' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'MovieName' = 'The Bodyguard'
                        'Year'       = '1982'
                        'Rating'     = '9'
                        'Genre'      = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Matrix'
                        'Year'       = '1999'
                        'Rating'     = '8'
                        'Genre'      = 'Sci-Fi'
                    }

                    [PSCustomObject]@{
                        'MovieName' = 'Skyfall'
                        'Year'       = '2012'
                        'Rating'     = '9'
                        'Genre'      = 'Thriller'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre -DataOnly -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'MovieName' = 'The Bodyguard'
                        'Year'       = '1982'
                        'Rating'     = '9'
                        'Genre'      = 'Thriller'
                        'Country'    = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Matrix'
                        'Year'       = '1999'
                        'Rating'     = '8'
                        'Genre'      = 'Sci-Fi'
                        'Country'    = $null
                    }

                    [PSCustomObject]@{
                        'MovieName' = 'Skyfall'
                        'Year'       = '2012'
                        'Rating'     = '9'
                        'Genre'      = 'Thriller'
                        'Country'    = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre, Country -DataOnly -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                $ExpectedResult = [PSCustomObject]@{
                    'MovieName' = 'Skyfall'
                    'Year'      = '2012'
                    'Rating'    = '9'
                    'Genre'     = 'Thriller'
                    'Country'   = $null
                }
                
                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre, Country -DataOnly -TopRow 4
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
                
                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre, Country -DataOnly  -TopRow 5
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre, Country -DataOnly -TopRow 6 | Should BeNullOrEmpty
            }
            it 'NoHeader' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'P1' = 'Movie name'
                        'P2' = 'Year'
                        'P3' = 'Rating'
                        'P4' = $null
                        'P5' = 'Genre'
                    }
                    [PSCustomObject]@{
                        'P1' = 'The Bodyguard'
                        'P2' = '1982'
                        'P3' = '9'
                        'P4' = $null
                        'P5' = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'P1' = 'The Matrix'
                        'P2' = '1999'
                        'P3' = '8'
                        'P4' = $null
                        'P5' = 'Sci-Fi'
                    }
                    [PSCustomObject]@{
                        'P1' = $null
                        'P2' = $null
                        'P3' = $null
                        'P4' = $null
                        'P5' = $null
                    }
                    [PSCustomObject]@{
                        'P1' = 'Skyfall'
                        'P2' = '2012'
                        'P3' = '9'
                        'P4' = $null
                        'P5' = 'Thriller'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -NoHeader
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'NoHeader and TopRow' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'P1' = 'The Bodyguard'
                        'P2' = '1982'
                        'P3' = '9'
                        'P4' = $null
                        'P5' = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'P1' = 'The Matrix'
                        'P2' = '1999'
                        'P3' = '8'
                        'P4' = $null
                        'P5' = 'Sci-Fi'
                    }
                    [PSCustomObject]@{
                        'P1' = $null
                        'P2' = $null
                        'P3' = $null
                        'P4' = $null
                        'P5' = $null
                    }
                    [PSCustomObject]@{
                        'P1' = 'Skyfall'
                        'P2' = '2012'
                        'P3' = '9'
                        'P4' = $null
                        'P5' = 'Thriller'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -NoHeader -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'P1' = $null
                        'P2' = $null
                        'P3' = $null
                        'P4' = $null
                        'P5' = $null
                    }
                    [PSCustomObject]@{
                        'P1' = 'Skyfall'
                        'P2' = '2012'
                        'P3' = '9'
                        'P4' = $null
                        'P5' = 'Thriller'
                    }
                )
                $Result = Import-Excel -Path $Path -WorksheetName Test -NoHeader -TopRow 4
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
                
                $ExpectedResult = [PSCustomObject]@{
                    'P1' = 'Skyfall'
                    'P2' = '2012'
                    'P3' = '9'
                    'P4' = $null
                    'P5' = 'Thriller'
                }
                
                $Result = Import-Excel -Path $Path -WorksheetName Test -NoHeader -TopRow 5
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                Import-Excel -Path $Path -WorksheetName Test -NoHeader -TopRow 6 | Should BeNullOrEmpty
            }
            it 'NoHeader and DataOnly' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'P1' = 'Movie name'
                        'P2' = 'Year'
                        'P3' = 'Rating'
                        'P4' = 'Genre'
                    }
                    [PSCustomObject]@{
                        'P1' = 'The Bodyguard'
                        'P2' = '1982'
                        'P3' = '9'
                        'P4' = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'P1' = 'The Matrix'
                        'P2' = '1999'
                        'P3' = '8'
                        'P4' = 'Sci-Fi'
                    }
                    [PSCustomObject]@{
                        'P1' = 'Skyfall'
                        'P2' = '2012'
                        'P3' = '9'
                        'P4' = 'Thriller'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -NoHeader -DataOnly
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'NoHeader, DataOnly and TopRow' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'P1' = 'The Bodyguard'
                        'P2' = '1982'
                        'P3' = '9'
                        'P4' = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'P1' = 'The Matrix'
                        'P2' = '1999'
                        'P3' = '8'
                        'P4' = 'Sci-Fi'
                    }
                    [PSCustomObject]@{
                        'P1' = 'Skyfall'
                        'P2' = '2012'
                        'P3' = '9'
                        'P4' = 'Thriller'
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -NoHeader -DataOnly -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                $ExpectedResult = [PSCustomObject]@{
                    'P1' = 'Skyfall'
                    'P2' = '2012'
                    'P3' = '9'
                    'P4' = 'Thriller'
                }
                
                $Result = Import-Excel -Path $Path -WorksheetName Test -NoHeader -DataOnly -TopRow 4
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                $Result = Import-Excel -Path $Path -WorksheetName Test -NoHeader -DataOnly -TopRow 5
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                Import-Excel -Path $Path -WorksheetName Test -NoHeader -DataOnly -TopRow 6 | Should BeNullOrEmpty
            }
        }
        Describe 'blank rows and columns with missing headers' {

            #region Create test file
            <#
                ---------------------------------------------------------------------------------------------------
                |           A            B            C          D         E               F          G           |
                |1     Movie name                     Rating                                         Director     |
                |2     The Bodyguard                  9                    Thriller                  Mick Jackson |
                |3     The Matrix      1999           8                                              Wachowski    |
                |4                                                                                                |
                |5     Skyfall         2012           9                    Thriller                  Sam Mendes   |
                |6                                    10                                                          |
                ---------------------------------------------------------------------------------------------------
            #>

            $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
            $Excel = New-Object OfficeOpenXml.ExcelPackage $Path
            $Worksheet = $Excel | Add-WorkSheet -WorkSheetname Test

            # Row, Column
            $Worksheet.Cells[1, 1].Value = 'Movie name'
            $Worksheet.Cells[1, 3].Value = 'Rating'
            $Worksheet.Cells[1, 7].Value = 'Director'
            $Worksheet.Cells[2, 1].Value = 'The Bodyguard'
            $Worksheet.Cells[2, 3].Value = '9'
            $Worksheet.Cells[2, 5].Value = 'Thriller'
            $Worksheet.Cells[2, 7].Value = 'Mick Jackson'
            $Worksheet.Cells[3, 1].Value = 'The Matrix'
            $Worksheet.Cells[3, 2].Value = '1999'
            $Worksheet.Cells[3, 3].Value = '8'
            $Worksheet.Cells[3, 7].Value = 'Wachowski'
            $Worksheet.Cells[5, 1].Value = 'Skyfall'
            $Worksheet.Cells[5, 2].Value = '2012'
            $Worksheet.Cells[5, 3].Value = '9'
            $Worksheet.Cells[5, 5].Value = 'Thriller'
            $Worksheet.Cells[5, 7].Value = 'Sam Mendes'
            $Worksheet.Cells[6, 3].Value = '10'

            $Excel.Save()
            $Excel.Dispose()
            #endregion

            it 'Default' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'Movie name' = 'The Bodyguard'
                        'Rating'     = '9'
                        'Director'   = 'Mick Jackson'
                    }
                    [PSCustomObject]@{
                        'Movie name' = 'The Matrix'
                        'Rating'     = '8'
                        'Director'   = 'Wachowski'
                    }
                    [PSCustomObject]@{
                        'Movie name' = $null
                        'Rating'     = $null
                        'Director'   = $null
                    }
                    [PSCustomObject]@{
                        'Movie name' = 'Skyfall'
                        'Rating'     = '9'
                        'Director'   = 'Sam Mendes'
                    }
                    [PSCustomObject]@{
                        'Movie name' = $null
                        'Rating'     = '10'
                        'Director'   = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'Default and TopRow' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'The Bodyguard' = 'The Matrix'
                        '9'             = '8'
                        'Thriller'      = $null
                        'Mick Jackson'  = 'Wachowski'
                    }
                    [PSCustomObject]@{
                        'The Bodyguard' = $null
                        '9'             = $null
                        'Thriller'      = $null
                        'Mick Jackson'  = $null
                    }
                    [PSCustomObject]@{
                        'The Bodyguard' = 'Skyfall'
                        '9'             = '9'
                        'Thriller'      = 'Thriller'
                        'Mick Jackson'  = 'Sam Mendes'
                    }
                    [PSCustomObject]@{
                        'The Bodyguard' = $null
                        '9'             = '10'
                        'Thriller'      = $null
                        'Mick Jackson'  = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'Default and DataOnly' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'Movie name' = 'The Bodyguard'
                        'Rating'     = '9'
                        'Director'   = 'Mick Jackson'
                    }
                    [PSCustomObject]@{
                        'Movie name' = 'The Matrix'
                        'Rating'     = '8'
                        'Director'   = 'Wachowski'
                    }
                    [PSCustomObject]@{
                        'Movie name' = 'Skyfall'
                        'Rating'     = '9'
                        'Director'   = 'Sam Mendes'
                    }
                    [PSCustomObject]@{
                        'Movie name' = $null
                        'Rating'     = '10'
                        'Director'   = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -DataOnly
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'Default, DataOnly and TopRow' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'The Bodyguard' = 'The Matrix'
                        '9'             = '8'
                        'Thriller'      = $null
                        'Mick Jackson'  = 'Wachowski'
                    }
                    [PSCustomObject]@{
                        'The Bodyguard' = 'Skyfall'
                        '9'             = '9'
                        'Thriller'      = 'Thriller'
                        'Mick Jackson'  = 'Sam Mendes'
                    }
                    [PSCustomObject]@{
                        'The Bodyguard' = $null
                        '9'             = '10'
                        'Thriller'      = $null
                        'Mick Jackson'  = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -DataOnly -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'HeaderName' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'MovieName' = 'Movie name'
                        'Year'      = $null
                        'Rating'    = 'Rating'
                        'Genre'     = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Bodyguard'
                        'Year'      = $null
                        'Rating'    = '9'
                        'Genre'     = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Matrix'
                        'Year'      = '1999'
                        'Rating'    = '8'
                        'Genre'     = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = $null
                        'Year'      = $null
                        'Rating'    = $null
                        'Genre'     = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'Skyfall'
                        'Year'      = '2012'
                        'Rating'    = '9'
                        'Genre'     = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = $null
                        'Year'      = $null
                        'Rating'    = '10'
                        'Genre'     = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'MovieName' = 'Movie name'
                        'Year'      = $null
                        'Rating'    = 'Rating'
                        'Genre'     = $null
                        'Country'   = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Bodyguard'
                        'Year'      = $null
                        'Rating'    = '9'
                        'Genre'     = $null
                        'Country'   = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Matrix'
                        'Year'      = '1999'
                        'Rating'    = '8'
                        'Genre'     = $null
                        'Country'   = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = $null
                        'Year'      = $null
                        'Rating'    = $null
                        'Genre'     = $null
                        'Country'   = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'Skyfall'
                        'Year'      = '2012'
                        'Rating'    = '9'
                        'Genre'     = $null
                        'Country'   = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'MovieName' = $null
                        'Year'      = $null
                        'Rating'    = '10'
                        'Genre'     = $null
                        'Country'   = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre, Country
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'HeaderName and TopRow' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'MovieName' = 'The Bodyguard'
                        'Year'      = $null
                        'Rating'    = '9'
                        'Genre'     = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Matrix'
                        'Year'      = '1999'
                        'Rating'    = '8'
                        'Genre'     = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = $null
                        'Year'      = $null
                        'Rating'    = $null
                        'Genre'     = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'Skyfall'
                        'Year'      = '2012'
                        'Rating'    = '9'
                        'Genre'     = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = $null
                        'Year'      = $null
                        'Rating'    = '10'
                        'Genre'     = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'MovieName' = 'The Bodyguard'
                        'Year'      = $null
                        'Rating'    = '9'
                        'Genre'     = $null
                        'Country'   = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Matrix'
                        'Year'      = '1999'
                        'Rating'    = '8'
                        'Genre'     = $null
                        'Country'   = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = $null
                        'Year'      = $null
                        'Rating'    = $null
                        'Genre'     = $null
                        'Country'   = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'Skyfall'
                        'Year'      = '2012'
                        'Rating'    = '9'
                        'Genre'     = $null
                        'Country'   = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'MovieName' = $null
                        'Year'      = $null
                        'Rating'    = '10'
                        'Genre'     = $null
                        'Country'   = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre, Country -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'HeaderName and DataOnly' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'MovieName' = 'Movie name'
                        'Year'      = $null
                        'Rating'    = 'Rating'
                        'Genre'     = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Bodyguard'
                        'Year'      = $null
                        'Rating'    = '9'
                        'Genre'     = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Matrix'
                        'Year'      = '1999'
                        'Rating'    = '8'
                        'Genre'     = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'Skyfall'
                        'Year'      = '2012'
                        'Rating'    = '9'
                        'Genre'     = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'MovieName' = $null
                        'Year'      = $null
                        'Rating'    = '10'
                        'Genre'     = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre -DataOnly
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'MovieName' = 'Movie name'
                        'Year'      = $null
                        'Rating'    = 'Rating'
                        'Genre'     = $null
                        'Country'   = 'Director'
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Bodyguard'
                        'Year'      = $null
                        'Rating'    = '9'
                        'Genre'     = 'Thriller'
                        'Country'   = 'Mick Jackson'
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Matrix'
                        'Year'      = '1999'
                        'Rating'    = '8'
                        'Genre'     = $null
                        'Country'   = 'Wachowski'
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'Skyfall'
                        'Year'      = '2012'
                        'Rating'    = '9'
                        'Genre'     = 'Thriller'
                        'Country'   = 'Sam Mendes'
                    }
                    [PSCustomObject]@{
                        'MovieName' = $null
                        'Year'      = $null
                        'Rating'    = '10'
                        'Genre'     = $null
                        'Country'   = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre, Country -DataOnly
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'HeaderName, DataOnly and TopRow' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'MovieName' = 'The Bodyguard'
                        'Year'      = $null
                        'Rating'    = '9'
                        'Genre'     = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Matrix'
                        'Year'      = '1999'
                        'Rating'    = '8'
                        'Genre'     = $null
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'Skyfall'
                        'Year'      = '2012'
                        'Rating'    = '9'
                        'Genre'     = 'Thriller'
                    }
                    [PSCustomObject]@{
                        'MovieName' = $null
                        'Year'      = $null
                        'Rating'    = '10'
                        'Genre'     = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre -DataOnly -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult

                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'MovieName' = 'The Bodyguard'
                        'Year'      = $null
                        'Rating'    = '9'
                        'Genre'     = 'Thriller'
                        'Country'   = 'Mick Jackson'
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'The Matrix'
                        'Year'      = '1999'
                        'Rating'    = '8'
                        'Genre'     = $null
                        'Country'   = 'Wachowski'
                    }
                    [PSCustomObject]@{
                        'MovieName' = 'Skyfall'
                        'Year'      = '2012'
                        'Rating'    = '9'
                        'Genre'     = 'Thriller'
                        'Country'   = 'Sam Mendes'
                    }
                    [PSCustomObject]@{
                        'MovieName' = $null
                        'Year'      = $null
                        'Rating'    = '10'
                        'Genre'     = $null
                        'Country'   = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -HeaderName MovieName, Year, Rating, Genre, Country -DataOnly -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'NoHeader' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'P1' = 'Movie name'
                        'P2' = $null
                        'P3' = 'Rating'
                        'P4' = $null
                        'P5' = $null
                        'P6' = $null
                        'P7' = 'Director'
                    }
                    [PSCustomObject]@{
                        'P1' = 'The Bodyguard'
                        'P2' = $null
                        'P3' = '9'
                        'P4' = $null
                        'P5' = 'Thriller'
                        'P6' = $null
                        'P7' = 'Mick Jackson'
                    }
                    [PSCustomObject]@{
                        'P1' = 'The Matrix'
                        'P2' = '1999'
                        'P3' = '8'
                        'P4' = $null
                        'P5' = $null
                        'P6' = $null
                        'P7' = 'Wachowski'
                    }
                    [PSCustomObject]@{
                        'P1' = $null
                        'P2' = $null
                        'P3' = $null
                        'P4' = $null
                        'P5' = $null
                        'P6' = $null
                        'P7' = $null
                    }
                    [PSCustomObject]@{
                        'P1' = 'Skyfall'
                        'P2' = '2012'
                        'P3' = '9'
                        'P4' = $null
                        'P5' = 'Thriller'
                        'P6' = $null
                        'P7' = 'Sam Mendes'
                    }
                    [PSCustomObject]@{
                        'P1' = $null
                        'P2' = $null
                        'P3' = '10'
                        'P4' = $null
                        'P5' = $null
                        'P6' = $null
                        'P7' = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -NoHeader
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'NoHeader and TopRow' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'P1' = 'The Bodyguard'
                        'P2' = $null
                        'P3' = '9'
                        'P4' = $null
                        'P5' = 'Thriller'
                        'P6' = $null
                        'P7' = 'Mick Jackson'
                    }
                    [PSCustomObject]@{
                        'P1' = 'The Matrix'
                        'P2' = '1999'
                        'P3' = '8'
                        'P4' = $null
                        'P5' = $null
                        'P6' = $null
                        'P7' = 'Wachowski'
                    }
                    [PSCustomObject]@{
                        'P1' = $null
                        'P2' = $null
                        'P3' = $null
                        'P4' = $null
                        'P5' = $null
                        'P6' = $null
                        'P7' = $null
                    }
                    [PSCustomObject]@{
                        'P1' = 'Skyfall'
                        'P2' = '2012'
                        'P3' = '9'
                        'P4' = $null
                        'P5' = 'Thriller'
                        'P6' = $null
                        'P7' = 'Sam Mendes'
                    }
                    [PSCustomObject]@{
                        'P1' = $null
                        'P2' = $null
                        'P3' = '10'
                        'P4' = $null
                        'P5' = $null
                        'P6' = $null
                        'P7' = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -NoHeader -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'NoHeader and DataOnly' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'P1' = 'Movie name'
                        'P2' = $null
                        'P3' = 'Rating'
                        'P4' = $null
                        'P5' = 'Director'
                    }
                    [PSCustomObject]@{
                        'P1' = 'The Bodyguard'
                        'P2' = $null
                        'P3' = '9'
                        'P4' = 'Thriller'
                        'P5' = 'Mick Jackson'
                    }
                    [PSCustomObject]@{
                        'P1' = 'The Matrix'
                        'P2' = '1999'
                        'P3' = '8'
                        'P4' = $null
                        'P5' = 'Wachowski'
                    }
                    [PSCustomObject]@{
                        'P1' = 'Skyfall'
                        'P2' = '2012'
                        'P3' = '9'
                        'P4' = 'Thriller'
                        'P5' = 'Sam Mendes'
                    }
                    [PSCustomObject]@{
                        'P1' = $null
                        'P2' = $null
                        'P3' = '10'
                        'P4' = $null
                        'P5' = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -NoHeader -DataOnly
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
            it 'NoHeader, DataOnly and TopRow' {
                $ExpectedResult = @(
                    [PSCustomObject]@{
                        'P1' = 'The Bodyguard'
                        'P2' = $null
                        'P3' = '9'
                        'P4' = 'Thriller'
                        'P5' = 'Mick Jackson'
                    }
                    [PSCustomObject]@{
                        'P1' = 'The Matrix'
                        'P2' = '1999'
                        'P3' = '8'
                        'P4' = $null
                        'P5' = 'Wachowski'
                    }
                    [PSCustomObject]@{
                        'P1' = 'Skyfall'
                        'P2' = '2012'
                        'P3' = '9'
                        'P4' = 'Thriller'
                        'P5' = 'Sam Mendes'
                    }
                    [PSCustomObject]@{
                        'P1' = $null
                        'P2' = $null
                        'P3' = '10'
                        'P4' = $null
                        'P5' = $null
                    }
                )

                $Result = Import-Excel -Path $Path -WorksheetName Test -NoHeader -DataOnly -TopRow 2
                Assert-Equivalent -Actual $Result -Expected $ExpectedResult
            }
        }
    }
}

Context 'special cases' {
    in $TestDrive {
        Describe 'duplicate column headers' {
            it 'worksheet' {
                #region Create test file
                <#
                    ----------------------------------------------
                    |           A           B            C       |
                    |1     First Name    first name   Address    |
                    |2     Chuck         Norris       California |
                    |3     Jean-Claude   Vandamme     Brussels   |
                    ----------------------------------------------
                #>

                $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
                $Excel = New-Object OfficeOpenXml.ExcelPackage $Path
                $Worksheet = $Excel | Add-WorkSheet -WorkSheetname Test

                # Row, Column
                $Worksheet.Cells[1, 1].Value = 'First Name'
                $Worksheet.Cells[1, 2].Value = 'first name'
                $Worksheet.Cells[1, 3].Value = 'Address'
                $Worksheet.Cells[2, 1].Value = 'Chuck'
                $Worksheet.Cells[2, 2].Value = 'Norris'
                $Worksheet.Cells[2, 3].Value = 'California'
                $Worksheet.Cells[3, 1].Value = 'Jean-Claude'
                $Worksheet.Cells[3, 2].Value = 'Vandamme'
                $Worksheet.Cells[3, 3].Value = 'Brussels'

                $Excel.Save()
                $Excel.Dispose()
                #endregion

                {Import-Excel -Path $Path -WorksheetName Test} | Should Throw 'Duplicate column headers found'

                #region Create test file
                Remove-Item .\* -Force
                <#
                    ----------------------------------------------
                    |           A           B            C       |
                    |1                                           |
                    |2     Fruit         Fruit      Color        |
                    |3     Kiwi                     Green        |
                    ----------------------------------------------
                #>

                $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
                $Excel = New-Object OfficeOpenXml.ExcelPackage $Path
                $Worksheet = $Excel | Add-WorkSheet -WorkSheetname Test

                # Row, Column
                $Worksheet.Cells[2, 1].Value = 'Fruit'
                $Worksheet.Cells[2, 2].Value = 'Fruit'
                $Worksheet.Cells[2, 3].Value = 'Color'
                $Worksheet.Cells[3, 1].Value = 'Kiwi'
                $Worksheet.Cells[3, 3].Value = 'Green'

                $Excel.Save()
                $Excel.Dispose()
                #endregion

                {Import-Excel -Path $Path -WorksheetName Test -TopRow 2} | Should Throw 'Duplicate column headers found'
            }
            it 'HeaderName parameter' {
                {Import-Excel -Path $Path -WorksheetName Test -HeaderName Apples, Apples, Kiwi} | Should Throw 'Duplicate column headers found'
            }
        }
    }
}