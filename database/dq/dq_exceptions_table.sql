/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE [dq].[dq_exceptions](
	[dq_exception_id] [bigint] IDENTITY(1,1) NOT NULL,
	[rule_id] [int] NOT NULL,
	[etl_run_id] [bigint] NULL,
	[object_name] [nvarchar](150) NOT NULL,
	[record_id] [varchar](18) NULL,
	[exception_value] [nvarchar](max) NULL,
	[exception_details] [nvarchar](max) NULL,
	[first_detected_at] [datetime2](7) NOT NULL,
	[last_detected_at] [datetime2](7) NOT NULL,
	[resolution_status] [nvarchar](50) NOT NULL,
	[resolved_at] [datetime2](7) NULL,
	[resolved_by] [nvarchar](200) NULL,
PRIMARY KEY CLUSTERED 
(
	[dq_exception_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_dq_exceptions_open] ON [dq].[dq_exceptions]
(
	[resolution_status] ASC,
	[object_name] ASC,
	[rule_id] ASC
)
INCLUDE([record_id],[last_detected_at]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dq].[dq_exceptions] ADD  DEFAULT (sysdatetime()) FOR [first_detected_at]
GO
ALTER TABLE [dq].[dq_exceptions] ADD  DEFAULT (sysdatetime()) FOR [last_detected_at]
GO
ALTER TABLE [dq].[dq_exceptions] ADD  DEFAULT ('Open') FOR [resolution_status]
GO
ALTER TABLE [dq].[dq_exceptions]  WITH CHECK ADD  CONSTRAINT [FK_dq_exceptions_rule] FOREIGN KEY([rule_id])
REFERENCES [dq].[dq_rule_catalog] ([rule_id])
GO
ALTER TABLE [dq].[dq_exceptions] CHECK CONSTRAINT [FK_dq_exceptions_rule]
GO
