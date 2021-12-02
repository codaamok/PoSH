$inputData = Get-Content $pwd\aoc-day2.txt

# Part 1
$horizontal = 0
$depth = 0

switch -Regex ($inputData) {
    "forward" {
        $null, $int = $_.split(" ")
        $horizontal += $int
    }
    "down" {
        $null, $int = $_.split(" ")
        $depth += $int
    }
    "up" {
        $null, $int = $_.split(" ")
        $depth -= $int
    }
}

$horizontal * $depth

# Part 2

$horizontal = 0
$depth = 0
$aim = 0

switch -Regex ($inputData) {
    "forward" {
        $null, [int]$int = $_.split(" ")
        $horizontal += $int
        $depth += ($int * $aim)
    }
    "down" {
        $null, [int]$int = $_.split(" ")
        $aim += $int
    }
    "up" {
        $null, [int]$int = $_.split(" ")
        $aim -= $int
    }
}

$horizontal * $depth
