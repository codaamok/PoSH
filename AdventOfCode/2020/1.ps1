[int[]]$Expenses = Get-Content .\1.txt 

# Part 1
foreach ($ExpenseA in $Expenses) {
    foreach ($ExpenseB in $Expenses) {
        if (($ExpenseA + $ExpenseB) -eq 2020) {
            Write-Output ("{0} and {1}" -f $ExpenseA, $ExpenseB)
        }
    }
}

# Part 2
foreach ($ExpenseA in $Expenses) {
    foreach ($ExpenseB in $Expenses) {
        foreach ($ExpenseC in $Expenses) {
            if (($ExpenseA + $ExpenseB + $ExpenseC) -eq 2020) {
                Write-Output ("{0}, {1} and {2}" -f $ExpenseA, $ExpenseB, $ExpenseC)
            }
        }
    }
}
