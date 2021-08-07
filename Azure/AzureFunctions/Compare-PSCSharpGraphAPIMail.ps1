
$Functions = @(
    [PSCustomObject]@{
        FunctionAppName = "GraphAPI-Mail-CSharp"
        ResourceGroupName = "RG-GraphAPIMailCSharp"
    },
    [PSCustomObject]@{
        FunctionAppName = "GraphAPI-Mail-PS"
        ResourceGroupName = "RG-GraphAPIMailPS"
    }
)

$Iterations = 100

foreach ($Function in $Functions) {

    $Results = 1..$Iterations | ForEach-Object {
        Stop-AzFunctionApp -Name "GraphAPI-Mail-CSharp" -ResourceGroupName "RG-GraphAPIMailCSharp" -Force
    
        while ((Get-AzFunctionApp -Name "GraphAPI-Mail-CSharp" -ResourceGroupName "RG-GraphAPIMailCSharp").State -ne "Stopped") {
            Write-Host "Waiting for Function App to stop"
            Start-Sleep -Seconds 3
        }
    
        Start-AzFunctionApp -Name "GraphAPI-Mail-CSharp" -ResourceGroupName "RG-GraphAPIMailCSharp"
    
        while ((Get-AzFunctionApp -Name "GraphAPI-Mail-CSharp" -ResourceGroupName "RG-GraphAPIMailCSharp").State -ne "Running") {
            Write-Host "Waiting for Function App to start"
            Start-Sleep -Seconds 3
        }
    
        Write-Host "Waiting for 10 seconds before calling"
    
        Measure-Command -Expression { 
            Invoke-RestMethod -uri "https://graphapi-mail-csharp.azurewebsites.net/api/GraphAPI_Mail"
        }
    }

    $Function.AvgSeconds = $Results.TotalSeconds / $Iterations
    $Function.MinSeconds = $Results | Sort-Object -Property TotalSeconds | Select-Object -ExpandProperty TotalSeconds -First 1
    $Function.MaxSeconds = $Results | Sort-Object -Property TotalSeconds -Descending | Select-Object -ExpandProperty TotalSeconds -First 1

}
