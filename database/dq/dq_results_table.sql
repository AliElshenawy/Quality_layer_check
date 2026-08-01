/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE [dq].[dq_results](
	[dq_result_id] [bigint] IDENTITY(1,1) NOT NULL,
	[etl_run_id] [bigint] NULL,
	[object_name] [nvarchar](150) NOT NULL,
	[check_name] [nvarchar](200) NOT NULL,
	[severity] [nvarchar](20) NOT NULL,
	[rows_checked] [bigint] NULL,
	[failed_count] [bigint] NOT NULL,
	[check_status] [nvarchar](20) NOT NULL,
	[details] [nvarchar](max) NULL,
	[checked_at] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[dq_result_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dq].[dq_results] ADD  DEFAULT (sysdatetime()) FOR [checked_at]
GO
