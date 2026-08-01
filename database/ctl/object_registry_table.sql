/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE [ctl].[object_registry](
	[object_registry_id] [int] IDENTITY(1,1) NOT NULL,
	[source_schema] [sysname] NOT NULL,
	[source_table] [sysname] NOT NULL,
	[object_name]  AS (replace([source_table],N'salesforce_',N'')) PERSISTED,
	[id_column] [sysname] NULL,
	[watermark_column] [sysname] NULL,
	[deleted_flag_column] [sysname] NULL,
	[etl_run_column] [sysname] NULL,
	[staging_schema] [sysname] NOT NULL,
	[latest_view_name] [sysname] NULL,
	[is_active] [bit] NOT NULL,
	[discovered_at] [datetime2](7) NOT NULL,
	[updated_at] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_object_registry] PRIMARY KEY CLUSTERED 
(
	[object_registry_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_object_registry] UNIQUE NONCLUSTERED 
(
	[source_schema] ASC,
	[source_table] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [ctl].[object_registry] ADD  CONSTRAINT [DF_object_registry_staging_schema]  DEFAULT (N'staging') FOR [staging_schema]
GO
ALTER TABLE [ctl].[object_registry] ADD  CONSTRAINT [DF_object_registry_is_active]  DEFAULT ((1)) FOR [is_active]
GO
ALTER TABLE [ctl].[object_registry] ADD  CONSTRAINT [DF_object_registry_discovered_at]  DEFAULT (sysdatetime()) FOR [discovered_at]
GO
ALTER TABLE [ctl].[object_registry] ADD  CONSTRAINT [DF_object_registry_updated_at]  DEFAULT (sysdatetime()) FOR [updated_at]
GO
