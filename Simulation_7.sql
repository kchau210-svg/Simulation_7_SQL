USE AdventureWorks2022;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Reporting')
BEGIN
    EXEC('CREATE SCHEMA Reporting AUTHORIZATION dbo');
END;
GO

IF OBJECT_ID('Reporting.ExecutionLog', 'U') IS NULL
BEGIN
    CREATE TABLE Reporting.ExecutionLog (
        LogID INT IDENTITY(1,1) PRIMARY KEY,
        ProcedureName NVARCHAR(100),
        ExecutedSQL NVARCHAR(MAX),
        ExecutionDate DATETIME DEFAULT GETDATE(),
        ErrorMessage NVARCHAR(4000)
    );
END;
GO

IF COL_LENGTH('Reporting.ExecutionLog', 'ExecutionStatus') IS NULL
BEGIN
    ALTER TABLE Reporting.ExecutionLog
    ADD ExecutionStatus NVARCHAR(50);
END;
GO

IF COL_LENGTH('Reporting.ExecutionLog', 'ParameterValues') IS NULL
BEGIN
    ALTER TABLE Reporting.ExecutionLog
    ADD ParameterValues NVARCHAR(500);
END;
GO

CREATE OR ALTER PROCEDURE Reporting.DynamicSalesReport_Secure
    @TerritoryName NVARCHAR(100) = NULL,
    @SalesPersonName NVARCHAR(100) = NULL,
    @ProductCategory NVARCHAR(100) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX) = N'
        SELECT
            t.Name AS TerritoryName,
            p.FirstName + '' '' + p.LastName AS SalesPersonName,
            pc.Name AS ProductCategory,
            soh.OrderDate,
            sod.LineTotal AS TotalSalesAmount,
            sod.OrderQty AS OrderQuantity
        FROM Sales.SalesOrderHeader soh
        INNER JOIN Sales.SalesOrderDetail sod
            ON soh.SalesOrderID = sod.SalesOrderID
        INNER JOIN Sales.SalesPerson sp
            ON soh.SalesPersonID = sp.BusinessEntityID
        INNER JOIN Person.Person p
            ON sp.BusinessEntityID = p.BusinessEntityID
        INNER JOIN Sales.SalesTerritory t
            ON soh.TerritoryID = t.TerritoryID
        INNER JOIN Production.Product pr
            ON sod.ProductID = pr.ProductID
        INNER JOIN Production.ProductSubcategory ps
            ON pr.ProductSubcategoryID = ps.ProductSubcategoryID
        INNER JOIN Production.ProductCategory pc
            ON ps.ProductCategoryID = pc.ProductCategoryID
        WHERE 1 = 1';

    DECLARE @ParameterValues NVARCHAR(500) =
        'Territory=' + ISNULL(@TerritoryName, 'NULL') +
        ', SalesPerson=' + ISNULL(@SalesPersonName, 'NULL') +
        ', Category=' + ISNULL(@ProductCategory, 'NULL') +
        ', StartDate=' + ISNULL(CONVERT(NVARCHAR(30), @StartDate), 'NULL') +
        ', EndDate=' + ISNULL(CONVERT(NVARCHAR(30), @EndDate), 'NULL');

    IF @StartDate IS NOT NULL AND @EndDate IS NOT NULL AND @StartDate > @EndDate
    BEGIN
        INSERT INTO Reporting.ExecutionLog
            (ProcedureName, ExecutedSQL, ErrorMessage, ExecutionStatus, ParameterValues)
        VALUES
            ('Reporting.DynamicSalesReport_Secure', NULL, 'Invalid date range', 'Rejected', @ParameterValues);

        PRINT 'Invalid date range.';
        RETURN;
    END;

    IF (@TerritoryName IS NOT NULL AND
        (@TerritoryName LIKE '%--%' OR @TerritoryName LIKE '%;%' OR UPPER(@TerritoryName) LIKE '%DROP%' OR UPPER(@TerritoryName) LIKE '%EXEC%'))
       OR
       (@SalesPersonName IS NOT NULL AND
        (@SalesPersonName LIKE '%--%' OR @SalesPersonName LIKE '%;%' OR UPPER(@SalesPersonName) LIKE '%DROP%' OR UPPER(@SalesPersonName) LIKE '%EXEC%'))
       OR
       (@ProductCategory IS NOT NULL AND
        (@ProductCategory LIKE '%--%' OR @ProductCategory LIKE '%;%' OR UPPER(@ProductCategory) LIKE '%DROP%' OR UPPER(@ProductCategory) LIKE '%EXEC%'))
    BEGIN
        INSERT INTO Reporting.ExecutionLog
            (ProcedureName, ExecutedSQL, ErrorMessage, ExecutionStatus, ParameterValues)
        VALUES
            ('Reporting.DynamicSalesReport_Secure', NULL, 'Unsafe input detected', 'Rejected', @ParameterValues);

        PRINT 'Unsafe input detected. Execution rejected.';
        RETURN;
    END;

    IF @TerritoryName IS NOT NULL
        SET @SQL += N' AND t.Name = @TerritoryName';

    IF @SalesPersonName IS NOT NULL
        SET @SQL += N' AND (p.FirstName + '' '' + p.LastName) = @SalesPersonName';

    IF @ProductCategory IS NOT NULL
        SET @SQL += N' AND pc.Name = @ProductCategory';

    IF @StartDate IS NOT NULL
        SET @SQL += N' AND soh.OrderDate >= @StartDate';

    IF @EndDate IS NOT NULL
        SET @SQL += N' AND soh.OrderDate <= @EndDate';

    SET @SQL += N' ORDER BY soh.OrderDate DESC';

    BEGIN TRY
        EXEC sp_executesql
            @SQL,
            N'@TerritoryName NVARCHAR(100), @SalesPersonName NVARCHAR(100), @ProductCategory NVARCHAR(100), @StartDate DATE, @EndDate DATE',
            @TerritoryName, @SalesPersonName, @ProductCategory, @StartDate, @EndDate;

        INSERT INTO Reporting.ExecutionLog
            (ProcedureName, ExecutedSQL, ErrorMessage, ExecutionStatus, ParameterValues)
        VALUES
            ('Reporting.DynamicSalesReport_Secure', @SQL, NULL, 'Success', @ParameterValues);
    END TRY
    BEGIN CATCH
        INSERT INTO Reporting.ExecutionLog
            (ProcedureName, ExecutedSQL, ErrorMessage, ExecutionStatus, ParameterValues)
        VALUES
            ('Reporting.DynamicSalesReport_Secure', @SQL, ERROR_MESSAGE(), 'Failed', @ParameterValues);

        PRINT ERROR_MESSAGE();
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Reporting.DynamicSalesReport_Vulnerable
    @TerritoryName NVARCHAR(100) = NULL,
    @SalesPersonName NVARCHAR(100) = NULL,
    @ProductCategory NVARCHAR(100) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX) = '
        SELECT
            t.Name AS TerritoryName,
            p.FirstName + '' '' + p.LastName AS SalesPersonName,
            pc.Name AS ProductCategory,
            soh.OrderDate,
            sod.LineTotal AS TotalSalesAmount,
            sod.OrderQty AS OrderQuantity
        FROM Sales.SalesOrderHeader soh
        INNER JOIN Sales.SalesOrderDetail sod
            ON soh.SalesOrderID = sod.SalesOrderID
        INNER JOIN Sales.SalesPerson sp
            ON soh.SalesPersonID = sp.BusinessEntityID
        INNER JOIN Person.Person p
            ON sp.BusinessEntityID = p.BusinessEntityID
        INNER JOIN Sales.SalesTerritory t
            ON soh.TerritoryID = t.TerritoryID
        INNER JOIN Production.Product pr
            ON sod.ProductID = pr.ProductID
        INNER JOIN Production.ProductSubcategory ps
            ON pr.ProductSubcategoryID = ps.ProductSubcategoryID
        INNER JOIN Production.ProductCategory pc
            ON ps.ProductCategoryID = pc.ProductCategoryID
        WHERE 1 = 1';

    DECLARE @ParameterValues NVARCHAR(500) =
        'Territory=' + ISNULL(@TerritoryName, 'NULL') +
        ', SalesPerson=' + ISNULL(@SalesPersonName, 'NULL') +
        ', Category=' + ISNULL(@ProductCategory, 'NULL') +
        ', StartDate=' + ISNULL(CONVERT(NVARCHAR(30), @StartDate), 'NULL') +
        ', EndDate=' + ISNULL(CONVERT(NVARCHAR(30), @EndDate), 'NULL');

    IF @TerritoryName IS NOT NULL
        SET @SQL += ' AND t.Name = ''' + @TerritoryName + '''';

    IF @SalesPersonName IS NOT NULL
        SET @SQL += ' AND (p.FirstName + '' '' + p.LastName) = ''' + @SalesPersonName + '''';

    IF @ProductCategory IS NOT NULL
        SET @SQL += ' AND pc.Name = ''' + @ProductCategory + '''';

    IF @StartDate IS NOT NULL
        SET @SQL += ' AND soh.OrderDate >= ''' + CONVERT(NVARCHAR(30), @StartDate, 23) + '''';

    IF @EndDate IS NOT NULL
        SET @SQL += ' AND soh.OrderDate <= ''' + CONVERT(NVARCHAR(30), @EndDate, 23) + '''';

    SET @SQL += ' ORDER BY soh.OrderDate DESC';

    BEGIN TRY
        EXEC(@SQL);

        INSERT INTO Reporting.ExecutionLog
            (ProcedureName, ExecutedSQL, ErrorMessage, ExecutionStatus, ParameterValues)
        VALUES
            ('Reporting.DynamicSalesReport_Vulnerable', @SQL, NULL, 'Success', @ParameterValues);
    END TRY
    BEGIN CATCH
        INSERT INTO Reporting.ExecutionLog
            (ProcedureName, ExecutedSQL, ErrorMessage, ExecutionStatus, ParameterValues)
        VALUES
            ('Reporting.DynamicSalesReport_Vulnerable', @SQL, ERROR_MESSAGE(), 'Failed', @ParameterValues);

        PRINT ERROR_MESSAGE();
    END CATCH
END;
GO

CREATE OR ALTER VIEW Reporting.ExecutionSummary
AS
SELECT
    COUNT(*) AS TotalExecutions,
    SUM(CASE WHEN ExecutionStatus = 'Success' THEN 1 ELSE 0 END) AS SuccessfulExecutions,
    SUM(CASE WHEN ExecutionStatus = 'Failed' THEN 1 ELSE 0 END) AS FailedExecutions,
    SUM(CASE WHEN ExecutionStatus = 'Rejected' THEN 1 ELSE 0 END) AS RejectedExecutions
FROM Reporting.ExecutionLog;
GO

EXEC Reporting.DynamicSalesReport_Secure
    @TerritoryName = 'Northwest';

EXEC Reporting.DynamicSalesReport_Secure
    @TerritoryName = 'Northwest',
    @ProductCategory = 'Bikes',
    @StartDate = '2012-01-01',
    @EndDate = '2013-12-31';

EXEC Reporting.DynamicSalesReport_Secure
    @TerritoryName = 'DROP TABLE';

EXEC Reporting.DynamicSalesReport_Secure
    @StartDate = '2014-01-01',
    @EndDate = '2013-01-01';

EXEC Reporting.DynamicSalesReport_Vulnerable
    @TerritoryName = 'Northwest';

EXEC Reporting.DynamicSalesReport_Vulnerable
    @TerritoryName = 'Northwest'' OR 1=1 --';

SELECT * FROM Reporting.ExecutionLog;

SELECT * FROM Reporting.ExecutionSummary;