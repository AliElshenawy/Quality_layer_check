/* ============================================================================
   Create ADF managed identity user in SalesforceDW
   Usage (sqlcmd):
     sqlcmd -S <server>.database.windows.net -d SalesforceDW -G -N -C -b \
       -v ADF_OBJECT_ID="<GUID>" -i ctl/create_adf_sql_user.sql

   Notes:
   - Run as Microsoft Entra admin.
   - This script is idempotent for user creation and role membership.
   ============================================================================ */

:setvar ADF_OBJECT_ID ""

SET NOCOUNT ON;
GO

DECLARE @ObjectId nvarchar(64) = N'$(ADF_OBJECT_ID)';

IF @ObjectId IS NULL OR LTRIM(RTRIM(@ObjectId)) = N'' OR @ObjectId LIKE N'REPLACE%'
BEGIN
    THROW 50001, 'ADF_OBJECT_ID is required. Pass it with -v ADF_OBJECT_ID="<GUID>".', 1;
END;

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_principals
    WHERE name = N'quality-check-poc-adf'
)
BEGIN
    DECLARE @CreateUserSql nvarchar(max) =
        N'CREATE USER [quality-check-poc-adf] FROM EXTERNAL PROVIDER WITH OBJECT_ID = '''
        + REPLACE(@ObjectId, '''', '''''')
        + N''';';

    EXEC (@CreateUserSql);
END;

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals r ON r.principal_id = drm.role_principal_id
    JOIN sys.database_principals m ON m.principal_id = drm.member_principal_id
    WHERE r.name = N'db_owner'
      AND m.name = N'quality-check-poc-adf'
)
BEGIN
    ALTER ROLE db_owner ADD MEMBER [quality-check-poc-adf];
END;

SELECT name, type_desc
FROM sys.database_principals
WHERE name = N'quality-check-poc-adf';
GO
