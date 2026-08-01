/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE [dq].[technical_run](
	[dq_run_id] [uniqueidentifier] NOT NULL,
	[started_at] [datetime2](7) NOT NULL,
	[completed_at] [datetime2](7) NULL,
	[max_rows_per_object] [bigint] NOT NULL,
	[run_status] [varchar](20) NOT NULL,
	[error_message] [nvarchar](4000) NULL,
 CONSTRAINT [PK_technical_run] PRIMARY KEY CLUSTERED 
(
	[dq_run_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
