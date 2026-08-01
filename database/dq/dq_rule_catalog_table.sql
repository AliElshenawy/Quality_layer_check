/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE [dq].[dq_rule_catalog](
	[rule_id] [int] IDENTITY(1,1) NOT NULL,
	[object_name] [nvarchar](150) NOT NULL,
	[source_view] [sysname] NOT NULL,
	[check_name] [nvarchar](200) NOT NULL,
	[check_type] [nvarchar](50) NOT NULL,
	[target_column] [sysname] NULL,
	[severity] [nvarchar](20) NOT NULL,
	[description] [nvarchar](500) NULL,
	[is_active] [bit] NOT NULL,
	[created_at] [datetime2](7) NOT NULL,
	[rule_source] [nvarchar](100) NULL,
	[approval_status] [nvarchar](50) NULL,
	[process_name] [nvarchar](150) NULL,
	[rule_definition] [nvarchar](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[rule_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_dq_rule_catalog] UNIQUE NONCLUSTERED 
(
	[object_name] ASC,
	[check_name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dq].[dq_rule_catalog] ADD  DEFAULT ((1)) FOR [is_active]
GO
ALTER TABLE [dq].[dq_rule_catalog] ADD  DEFAULT (sysdatetime()) FOR [created_at]
GO
