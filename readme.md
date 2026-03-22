# Simulation 7 - Dynamic SQL Execution and Security

## Purpose
## This simulation demonstrates the difference between secure and vulnerable dynamic SQL in SQL Server using AdventureWorks2022.

## Procedures
- Reporting.DynamicSalesReport_Secure
- Reporting.DynamicSalesReport_Vulnerable

## Features
- Optional filtering parameters
- Parameterized dynamic SQL using sp_executesql
- Vulnerable version using EXEC(@SQL)
- Basic input validation
- Execution logging
- Execution summary view

## Testing Steps
1. Run the SQL script to create/update objects.
2. Execute the secure procedure with normal input.
3. Execute the secure procedure with multiple filters.
4. Execute the secure procedure with unsafe input.
5. Execute the vulnerable procedure with normal input.
6. Execute the vulnerable procedure with injection input.
7. View log entries.
8. View execution summary.

## Expected Results
- Secure procedure returns filtered results safely.
- Secure procedure rejects unsafe input.
- Vulnerable procedure is affected by injection input.
- All executions are recorded in Reporting.ExecutionLog.
- Summary view shows totals for success, failed, and rejected executions.