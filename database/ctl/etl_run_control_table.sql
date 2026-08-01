/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE [ctl].[etl_run_control](
	[run_id] [bigint] IDENTITY(1,1) NOT NULL,
	[object_name] [nvarchar](100) NOT NULL,
	[load_type] [nvarchar](20) NOT NULL,
	[start_time] [datetime2](7) NOT NULL,
	[end_time] [datetime2](7) NULL,
	[status] [nvarchar](20) NOT NULL,
	[rows_extracted] [bigint] NULL,
	[rows_loaded] [bigint] NULL,
	[error_message] [nvarchar](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[run_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [ctl].[etl_run_control] ADD  DEFAULT (sysdatetime()) FOR [start_time]
GO
ALTER TABLE [ctl].[etl_run_control] ADD  DEFAULT ('Running') FOR [status]
GO
