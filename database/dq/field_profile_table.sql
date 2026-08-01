/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE [dq].[field_profile](
	[profile_result_id] [bigint] IDENTITY(1,1) NOT NULL,
	[profile_run_id] [uniqueidentifier] NOT NULL,
	[object_registry_id] [int] NOT NULL,
	[object_name] [sysname] NOT NULL,
	[source_object] [nvarchar](600) NOT NULL,
	[column_id] [int] NOT NULL,
	[column_name] [sysname] NOT NULL,
	[sql_data_type] [sysname] NOT NULL,
	[approximate_total_rows] [bigint] NOT NULL,
	[sampled_rows] [bigint] NOT NULL,
	[sample_is_partial] [bit] NOT NULL,
	[null_count] [bigint] NOT NULL,
	[blank_count] [bigint] NOT NULL,
	[populated_count] [bigint] NOT NULL,
	[completeness_percentage] [decimal](12, 4) NULL,
	[approximate_distinct_count] [bigint] NULL,
	[minimum_text_length] [int] NULL,
	[maximum_text_length] [int] NULL,
	[profiled_at] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_field_profile] PRIMARY KEY CLUSTERED 
(
	[profile_result_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_field_profile_run_object] ON [dq].[field_profile]
(
	[profile_run_id] ASC,
	[object_registry_id] ASC,
	[column_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dq].[field_profile] ADD  CONSTRAINT [DF_field_profile_profiled_at]  DEFAULT (sysdatetime()) FOR [profiled_at]
GO
