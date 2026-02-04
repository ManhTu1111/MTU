use [AdventureWorks2008R2]

--1) Viết một batch khai báo biến @tongsoHD chứa tổng số hóa đơn của sản phẩm 
--có ProductID=’778’; nếu @tongsoHD>500 thì in ra chuỗi “Sản phẩm 778 có 
--trên 500 đơn hàng”, ngược lại thì in ra chuỗi “Sản phẩm 778 có ít đơn đặt 
--hàng” 

declare @tongsoHD int
select @tongsoHD = count(*)
from Sales.SalesOrderDetail
where ProductID = 778

if @tongsoHD > 500
	print N'Sản phẩm có trên 500 đơn hàng'
else
	print N'Sản phẩm có ít hơn 500 đơn hàng'

--2) Viết một đoạn Batch với tham số @makh và @n chứa số hóa đơn của khách 
--hàng @makh, tham số @nam chứa năm lập hóa đơn (ví dụ @nam=2008),   nếu 
--@n>0 thì in ra chuỗi: “Khách hàng @makh có @n hóa đơn trong năm 2008” 
--ngược lại nếu @n=0 thì in ra chuỗi “Khách hàng @makh không có hóa đơn nào 
--trong năm 2008” 

declare @makh int
declare @n int
declare @nam int

set @makh = 297
set @nam = 2008

select @n = count(*)
from sales.salesorderheader
where customerid = @makh and year(orderdate) = @nam

if @n > 0
    print N'khách hàng ' + cast(@makh as varchar) + N' có ' + cast(@n as varchar) + N' hóa đơn trong năm ' + cast(@nam as varchar)
else
    print N'khách hàng ' + cast(@makh as varchar) + N' không có hóa đơn nào trong năm ' + cast(@nam as varchar)

--3) Viết một batch tính số tiền giảm cho những hóa đơn (SalesOrderID) có tổng 
--tiền>100000, thông tin gồm [SalesOrderID], SubTotal=SUM([LineTotal]), 
--Discount (tiền giảm), với Discount được tính như sau: 
-- Những hóa đơn có SubTotal<100000 thì không giảm, 
-- SubTotal từ 100000 đến <120000 thì giảm 5% của SubTotal 
-- SubTotal từ 120000 đến <150000 thì giảm 10% của SubTotal 
-- SubTotal từ 150000 trở lên thì giảm 15% của SubTotal
--(Gợi ý: Dùng cấu trúc Case… When …Then …) 

select SalesOrderID, 
       sum(linetotal) as SubTotal,
       case 
           when sum(linetotal) < 100000 then 0
           when sum(linetotal) >= 100000 and sum(linetotal) < 120000 then sum(linetotal) * 0.05
           when sum(linetotal) >= 120000 and sum(linetotal) < 150000 then sum(linetotal) * 0.1
           else sum(linetotal) * 0.15
       end as Discount
from sales.salesorderdetail
group by salesorderid
having sum(linetotal) > 100000

--4) Viết một Batch với 3 tham số: @mancc, @masp, @soluongcc, chứa giá trị của 
--các field [ProductID],[BusinessEntityID],[OnOrderQty], với giá trị truyền cho 
--các biến @mancc, @masp (vd: @mancc=1650, @masp=4), thì chương trình sẽ 
--gán  giá  trị  tương  ứng  của  field  [OnOrderQty]  cho  biến  @soluongcc,  nếu 
--@soluongcc trả về giá trị là null thì in ra chuỗi “Nhà cung cấp 1650 không cung 
--cấp sản phẩm 4”, ngược lại (vd: @soluongcc=5) thì in chuỗi “Nhà cung cấp 1650 
--cung cấp sản phẩm 4 với số lượng là 5” 
--(Gợi ý: Dữ liệu lấy từ [Purchasing].[ProductVendor]) 

declare @mancc int
declare @masp int
declare @soluongcc int

set @mancc = 1650
set @masp = 4

select @soluongcc = onorderqty
from purchasing.productvendor
where businessentityid = @mancc and productid = @masp

if @soluongcc is null
    print N'nhà cung cấp ' + cast(@mancc as varchar) + N' không cung cấp sản phẩm ' + cast(@masp as varchar)
else
    print N'nhà cung cấp ' + cast(@mancc as varchar) + N' cung cấp sản phẩm ' + cast(@masp as varchar) + N' với số lượng là ' + cast(@soluongcc as varchar)


--5) Viết một batch thực hiện tăng lương giờ (Rate) của nhân viên trong 
--[HumanResources].[EmployeePayHistory] theo điều kiện sau: Khi tổng lương 
--giờ của tất cả nhân viên Sum(Rate)<6000 thì cập nhật tăng lương giờ lên 10%, 
--nếu sau khi cập nhật mà lương giờ cao nhất của nhân viên >150 thì dừng.

declare @tongluong money
declare @maxluong money

select @tongluong = sum(rate) 
from humanresources.employeepayhistory

if @tongluong < 6000
begin
    update humanresources.employeepayhistory
    set rate = rate * 1.1

    select @maxluong = max(rate)
    from humanresources.employeepayhistory

    if @maxluong > 150
    begin
        print N'dừng cập nhật vì lương giờ cao nhất vượt quá 150'
    end
    else
    begin
        print N'đã cập nhật lương giờ lên 10%'
    end
end
else
    print N'tổng lương giờ của nhân viên lớn hơn hoặc bằng 6000'
