$Passwords = Get-Content .\2.txt

foreach ($String in $Passwords) {
    $Regex = [Regex]::Match($String, "(?<minimum>\d+)-(?<maximum>\d+) (?<character>[a-zA-Z]): (?<password>.+)")
    if ($REgex)
}