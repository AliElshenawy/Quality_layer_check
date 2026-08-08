/* ============================================================================
   Contact — INCREMENTAL "latest" staging builder (proc).
   ----------------------------------------------------------------------------
   Maintains staging.contact_latest INCREMENTALLY from raw.salesforce_contact:
   only Ids whose SystemModstamp changed since ctl.staging_state are re-deduped
   and upserted (delete-changed + insert-latest); soft-deleted Ids drop out.

   Run:    EXEC staging.refresh_contact_latest;                 -- incremental
   Reset:  EXEC staging.refresh_contact_latest @FullRebuild=1;  -- truncate + rebuild

   Requires: staging.contact_latest (contact_latest_table.sql).
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [staging].[refresh_contact_latest]
    @FullRebuild BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @FullRebuild = 1
        TRUNCATE TABLE [staging].[contact_latest];

    DECLARE @wm DATETIME2(7) = NULL;
    IF @FullRebuild = 0
        SELECT @wm = [last_staging_watermark] FROM [ctl].[staging_state] WHERE [object_name] = N'contact';

    IF OBJECT_ID(N'tempdb..#chg') IS NOT NULL DROP TABLE #chg;
    SELECT DISTINCT CONVERT(VARCHAR(18), [Id]) AS id18
    INTO #chg
    FROM [raw].[salesforce_contact]
    WHERE [Id] IS NOT NULL
      AND (@wm IS NULL
           OR COALESCE(TRY_CONVERT(DATETIME2(7), [SystemModstamp], 127),
                       TRY_CONVERT(DATETIME2(7), [SystemModstamp])) > @wm);

    DECLARE @deleted INT = 0, @inserted INT = 0;

    DELETE t FROM [staging].[contact_latest] t JOIN #chg c ON c.id18 = CONVERT(VARCHAR(18), t.[Id]);
    SET @deleted = @@ROWCOUNT;

    ;WITH dedup AS
    (
        SELECT
            [Id], [Name], [FirstName], [LastName], [RecordTypeId], [IsDeleted],
            [Email], [Phone], [MobilePhone],
            [MailingStreet], [MailingCity], [MailingState], [MailingPostalCode], [MailingCountry],
            [External_Id__c], [Regional_Office_Code__c], [Gift_Aid_Status__c], [Is_Donor__c],
            [Guardian_ID__c], [Orphan_Mother_Is_Guardian__c], [Orphan_Guardian_First_Name__c], [Oprhan_Guardian_Last_Name__c], [Orphan_Guardian_Relationship__c], [Orphan_Mother_Not_Guardian_Reason__c], [Orphan_Is_Mother_Alive__c], [Orphan_Mothers_Cause_Of_Death__c], [Orphan_Mothers_Date_Of_Death__c], [Orphan_Mother_Death_Verification_Method__c],
            [SystemModstamp],
            ROW_NUMBER() OVER (PARTITION BY CONVERT(VARCHAR(18), [Id])
                ORDER BY COALESCE(TRY_CONVERT(DATETIME2(7), [SystemModstamp], 127),
                                  TRY_CONVERT(DATETIME2(7), [SystemModstamp])) DESC) AS rn,
            COUNT(*) OVER (PARTITION BY CONVERT(VARCHAR(18), [Id])) AS dup_cnt
        FROM [raw].[salesforce_contact]
        WHERE [Id] IS NOT NULL
          AND CONVERT(VARCHAR(18), [Id]) IN (SELECT id18 FROM #chg)
    )
    INSERT INTO [staging].[contact_latest]
    (
        [row_number],
        [Id], [Name], [FirstName], [LastName], [RecordTypeId], [IsDeleted],
        [Email], [Phone], [MobilePhone],
        [MailingStreet], [MailingCity], [MailingState], [MailingPostalCode], [MailingCountry],
        [External_Id__c], [Regional_Office_Code__c], [Gift_Aid_Status__c], [Is_Donor__c],
        [Guardian_ID__c], [Orphan_Mother_Is_Guardian__c], [Orphan_Guardian_First_Name__c], [Oprhan_Guardian_Last_Name__c], [Orphan_Guardian_Relationship__c], [Orphan_Mother_Not_Guardian_Reason__c], [Orphan_Is_Mother_Alive__c], [Orphan_Mothers_Cause_Of_Death__c], [Orphan_Mothers_Date_Of_Death__c], [Orphan_Mother_Death_Verification_Method__c],
        [SystemModstamp],
        [staging_is_duplicate], [staging_duplicate_count], [staging_created_at]
    )
    SELECT
        rn,
        [Id], [Name], [FirstName], [LastName], [RecordTypeId], [IsDeleted],
        [Email], [Phone], [MobilePhone],
        [MailingStreet], [MailingCity], [MailingState], [MailingPostalCode], [MailingCountry],
        [External_Id__c], [Regional_Office_Code__c], [Gift_Aid_Status__c], [Is_Donor__c],
        [Guardian_ID__c], [Orphan_Mother_Is_Guardian__c], [Orphan_Guardian_First_Name__c], [Oprhan_Guardian_Last_Name__c], [Orphan_Guardian_Relationship__c], [Orphan_Mother_Not_Guardian_Reason__c], [Orphan_Is_Mother_Alive__c], [Orphan_Mothers_Cause_Of_Death__c], [Orphan_Mothers_Date_Of_Death__c], [Orphan_Mother_Death_Verification_Method__c],
        [SystemModstamp],
        CASE WHEN dup_cnt > 1 THEN 1 ELSE 0 END,
        CASE WHEN dup_cnt > 1 THEN dup_cnt ELSE 0 END,
        GETUTCDATE()
    FROM dedup
    WHERE rn = 1
      AND COALESCE(LOWER(LTRIM(RTRIM(CONVERT(NVARCHAR(20), [IsDeleted])))), N'false')
          NOT IN (N'true', N'1', N'yes', N'y');
    SET @inserted = @@ROWCOUNT;

    DECLARE @newwm DATETIME2(7) =
    (
        SELECT MAX(COALESCE(TRY_CONVERT(DATETIME2(7), [SystemModstamp], 127),
                            TRY_CONVERT(DATETIME2(7), [SystemModstamp])))
        FROM [raw].[salesforce_contact]
    );

    MERGE [ctl].[staging_state] AS t
    USING (SELECT N'contact' AS object_name) AS s ON t.[object_name] = s.object_name
    WHEN MATCHED THEN UPDATE SET
        t.[last_staging_watermark] = @newwm, t.[last_run_at] = SYSUTCDATETIME(),
        t.[last_rows_merged] = @inserted, t.[last_rows_deleted] = @deleted
    WHEN NOT MATCHED THEN INSERT ([object_name], [last_staging_watermark], [last_run_at], [last_rows_merged], [last_rows_deleted])
        VALUES (N'contact', @newwm, SYSUTCDATETIME(), @inserted, @deleted);

    DROP TABLE #chg;
END;
GO
