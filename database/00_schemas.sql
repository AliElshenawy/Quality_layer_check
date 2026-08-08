/* ============================================================================
   Author: ENG Ahmed Hassan
   Origin: SalesforceDW_Structure_Only.sql (2026-07-26 SSMS structure export)
   ============================================================================ */

USE [SalesforceDW];
GO
CREATE SCHEMA [ctl]
GO
CREATE SCHEMA [dq]
GO
CREATE SCHEMA [mart]
GO
CREATE SCHEMA [raw]
GO
CREATE SCHEMA [staging]
GO
CREATE SCHEMA [writeback]
GO
IF SCHEMA_ID(N'clean') IS NULL EXEC (N'CREATE SCHEMA [clean];');
GO
