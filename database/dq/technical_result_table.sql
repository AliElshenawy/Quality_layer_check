/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE [dq].[technical_result](
	[result_id] [bigint] IDENTITY(1,1) NOT NULL,
	[dq_run_id] [uniqueidentifier] NOT NULL,
	[object_registry_id] [int] NOT NULL,
	[object_name] [sysname] NOT NULL,
	[source_object] [nvarchar](600) NOT NULL,
	[rule_code] [varchar](100) NOT NULL,
	[rule_description] [nvarchar](500) NOT NULL,
	[checked_rows] [bigint] NOT NULL,
	[failed_rows] [bigint] NOT NULL,
	[pass_percentage] [decimal](12, 4) NULL,
	[result_status] [varchar](20) NOT NULL,
	[checked_at] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_technical_result] PRIMARY KEY CLUSTERED 
(
	[result_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_technical_result_run] ON [dq].[technical_result]
(
	[dq_run_id] ASC,
	[object_registry_id] ASC,
	[rule_code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dq].[technical_result] ADD  CONSTRAINT [DF_technical_result_checked_at]  DEFAULT (sysdatetime()) FOR [checked_at]
GO
