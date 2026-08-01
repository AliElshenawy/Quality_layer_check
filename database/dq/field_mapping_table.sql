/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE [dq].[field_mapping](
	[field_mapping_id] [int] IDENTITY(1,1) NOT NULL,
	[business_object] [nvarchar](150) NOT NULL,
	[business_field] [nvarchar](200) NOT NULL,
	[source_object] [sysname] NOT NULL,
	[salesforce_api_field] [sysname] NULL,
	[mapping_status] [nvarchar](50) NOT NULL,
	[notes] [nvarchar](1000) NULL,
	[confirmed_by] [nvarchar](200) NULL,
	[confirmed_at] [datetime2](7) NULL,
	[created_at] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[field_mapping_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_dq_field_mapping] UNIQUE NONCLUSTERED 
(
	[business_object] ASC,
	[business_field] ASC,
	[source_object] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dq].[field_mapping] ADD  DEFAULT ('Pending Confirmation') FOR [mapping_status]
GO
ALTER TABLE [dq].[field_mapping] ADD  DEFAULT (sysdatetime()) FOR [created_at]
GO
