/****** Object:  StoredProcedure bonus.SP004_ModifyStaffBonus    Script Date: 03/14/2012 20:56:31 ******/
if exists 
(
  select * 
  from sys.objects 
  where object_id = object_id('bonus.SP004_ModifyStaffBonus') 
  and type in ('P', 'PC')
)
drop procedure bonus.SP004_ModifyStaffBonus
go

set ansi_nulls on
go

set quoted_identifier on
go

-- ===================================================================
-- NAME:
--   bonus.SP004_ModifyStaffBonus
-- 
-- COPYRIGHT:
--   Skysource Technologies (c) 2011
-- 
-- DESCRIPTION:
--   Modify staff bonus amount, include insert delete and update.
-- 
-- HISTORY:
--   2011-04-30  Tony Chi
--   File created.
-- ===================================================================

create procedure bonus.SP004_ModifyStaffBonus
  @SITE_ID nvarchar(50) = null,
  @STAFF_ID nvarchar(50) = null,
  @MONTH_START_DATE datetime = null,
  @BONUS_AMOUNT nvarchar(50) = null,
  @UPDATE_BY_ID nvarchar(50) = null,
  @STAFF_BONUS_KEY nvarchar(50) = null,
  @REMARK_SOURCE nvarchar(50) = null,
  @REMARK_CONTENT nvarchar(255) = null,
  @ACTION_TYPE nvarchar(10) = null,
  @STAFF_BONUS_CATEGORY_ID nvarchar(50) = null
as
  declare @strStaffInsertBonusCategoryID nvarchar(50) = null
  declare @intStaffBonusKey int = null
  declare @dtRecordInsertDate datetime = getdate()
  declare @dtMonthStartDate datetime = null
  
begin
  -- set NOCOUNT on added to prevent extra result sets from interfering with select statements.
  set nocount off;

  if @ACTION_TYPE = 'UPS'
  begin
    if @STAFF_BONUS_KEY is not null
    begin
      select @strStaffInsertBonusCategoryID = sb.BONUS_CATEGORY_ID
      from bonus.STAFF_BONUS sb
      inner join bonus.BONUS_CATEGORY bc on sb.BONUS_CATEGORY_ID = bc.BONUS_CATEGORY_ID
      where STAFF_BONUS_KEY = @STAFF_BONUS_KEY 

      if @strStaffInsertBonusCategoryID = @STAFF_BONUS_CATEGORY_ID
      begin
        -- 如果是調整獎金TYPE 必定是修改
     
        -- update A RECORD
        select @dtMonthStartDate = convert(nvarchar(10), MONTH_START_DATE, 120) 
        from bonus.STAFF_BONUS
        where STAFF_BONUS_KEY = @STAFF_BONUS_KEY 
     
        update bonus.REMARK set REMARK_CONTENT = @REMARK_CONTENT, UPDATE_TIMESTAMP = getdate(), UPDATE_BY_ID = @UPDATE_BY_ID
        where REMARK_RECORD_NO = @STAFF_BONUS_KEY
        
        update bonus.STAFF_BONUS set BONUS_AMOUNT = @BONUS_AMOUNT, UPDATE_TIMESTAMP = getdate(), UPDATE_BY_ID = @UPDATE_BY_ID
        where STAFF_BONUS_KEY = @STAFF_BONUS_KEY
      end 
      else
      begin
        -- 不同獎金格式是新增一筆調整獎金
        -- INSERT A NEW RECORD      
        insert into bonus.STAFF_BONUS (SITE_ID, STAFF_ID, MONTH_START_DATE, BONUS_REFER_KEY, BONUS_CATEGORY_ID, BONUS_AMOUNT, CREATE_TIMESTAMP, CREATE_BY_ID)
        values (@SITE_ID, @STAFF_ID, @MONTH_START_DATE, @strStaffInsertBonusCategoryID, @STAFF_BONUS_CATEGORY_ID, @BONUS_AMOUNT, @dtRecordInsertDate, @UPDATE_BY_ID)

        select @intStaffBonusKey = STAFF_BONUS_KEY
        from bonus.STAFF_BONUS
        where STAFF_ID = @STAFF_ID and MONTH_START_DATE = @MONTH_START_DATE 
        and BONUS_CATEGORY_ID = @STAFF_BONUS_CATEGORY_ID and CREATE_TIMESTAMP = @dtRecordInsertDate
      
        insert into bonus.REMARK (REMARK_SOURCE, REMARK_RECORD_NO, REMARK_CONTENT, CREATE_TIMESTAMP, CREATE_BY_ID)
        values (@REMARK_SOURCE, @intStaffBonusKey, @REMARK_CONTENT,  getdate(), @UPDATE_BY_ID)
      end 
    end -- @STAFF_BONUS_KEY is not null
    else
    begin
      -- INSERT A NEW RECORD NO REFER KEY
      insert into bonus.STAFF_BONUS (SITE_ID, STAFF_ID, MONTH_START_DATE, BONUS_CATEGORY_ID, BONUS_AMOUNT, CREATE_TIMESTAMP, CREATE_BY_ID)
      values (@SITE_ID, @STAFF_ID, @MONTH_START_DATE, @STAFF_BONUS_CATEGORY_ID, @BONUS_AMOUNT, @dtRecordInsertDate, @UPDATE_BY_ID)      

      select @intStaffBonusKey = STAFF_BONUS_KEY
      from bonus.STAFF_BONUS
      where STAFF_ID = @STAFF_ID and MONTH_START_DATE = @MONTH_START_DATE 
      and BONUS_CATEGORY_ID = @STAFF_BONUS_CATEGORY_ID and CREATE_TIMESTAMP = @dtRecordInsertDate
      
      insert into bonus.REMARK (REMARK_SOURCE, REMARK_RECORD_NO, REMARK_CONTENT, CREATE_TIMESTAMP, CREATE_BY_ID)
      values (@REMARK_SOURCE, @intStaffBonusKey, @REMARK_CONTENT,  getdate(), @UPDATE_BY_ID)
    end -- @STAFF_BONUS_KEY is not null
  end
  else if @ACTION_TYPE = 'DEL'
  begin
    if @STAFF_BONUS_KEY is not null
    begin
      delete from bonus.REMARK
      where REMARK_RECORD_NO = @STAFF_BONUS_KEY
      
      delete from bonus.STAFF_BONUS
      where STAFF_BONUS_KEY = @STAFF_BONUS_KEY
    end -- @STAFF_BONUS_KEY is not null
  end -- @ACTION_TYPE = 'DEL'
end

go


