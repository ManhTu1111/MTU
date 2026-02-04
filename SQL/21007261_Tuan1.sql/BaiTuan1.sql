--cau 2 Tao database QLBH--
use master
--Cau a--
create database QLBH
ON PRIMARY 
(name=QLBH_data1,
filename='T:\QLBH_data1.mdf',
size=10mb,
maxsize=40mb,
filegrowth=1mb)
LOG ON
(name=QLBH_Log,
filename='T:\QLBH_Log.idf',
size=6mb,
maxsize=8mb,
filegrowth=1mb)
go
--cau b--
use QLBH
exec sp_helpdb
exec sp_spaceused
exec sp_helpfile
--cau c--
alter database QLBH
add filegroup DuLieuQLBH
--cau d--
alter database QLBH
add file(name=QLBH_data2,
filename='T:\QLBH_data2.ndf',
size=10mb,
maxsize=20mb)
to filegroup DuLieuQLBH
--cau e--
exec sp_helpfile
--cau f--
--read only--
alter database QLBH
set read_only
--read write--
alter database QLBH
set read_write
--cau g--
alter database QLBH
modify file(name='QLBH_data1',size=50mb)
alter database QLBH
modify file(name='QLBH_Log',size=10mb)
/*
-Để thay đổi SIZE của các tập tin bằng công cụ Design ta ấn dấu cộng
ở database và ấn chuột phải vào QLBH và chọn propẻties và chọn file đến đây 
ta có thể chỉnh size, maxsize và filegrowth tùy ý
-Có thể thay đổi kích cỡ nhỏ hơn ban đầu và không thể chỉnh maxsize nhỏ hơn size
vì maxsize là giới hạn của tập tin mà size mà to hơn maxsize là vượt qua giới hạn của tập tin
*/

--cau 3--
create database QLSV
ON PRIMARY 
(name=QLBH_data1,
filename='T:\QLSV_data.mdf',
size=10mb,
maxsize=40mb,
filegrowth=1mb)
LOG ON
(name=QLBH_Log,
filename='T:\QLSV_Log.idf',
size=6mb,
maxsize=8mb,
filegrowth=1mb)
go
--a.--
--b.--
/*Không thể nhập bảng kết quả trước vì nó thuộc bảng nhiều nó dính phải bảng sinh vien và bảng mon hoc vì thế khi nhập sẽ lỗi
Nhập thứ tự 1 trước rồi mới đến nhiều.*/
--c.--
--d.--
use QLSV	
select *
from [LOP],[KETQUA]
/*kết quả sẽ hiển thị các bảng thuộc tính và các bộ đã nhập trước đó*/ 
--cau4--
/*
--a--
1.
Integer Types:
INT: Số nguyên.
BIGINT: Số nguyên lớn hơn.
SMALLINT: Số nguyên nhỏ hơn.
TINYINT: Số nguyên nhỏ nhất.
Decimal Types:

DECIMAL hoặc NUMERIC: Số thập phân cố định.
FLOAT: Số thập phân có độ chính xác thấp hơn.
Character Types:

CHAR(n): Ký tự có độ dài cố định.
VARCHAR(n): Ký tự có độ dài biến đổi.
TEXT: Dữ liệu văn bản có độ dài lớn hơn.
Date and Time Types:

DATE: Ngày.
TIME: Thời gian.
DATETIME: Ngày và thời gian.
Binary Types:

BINARY: Dãy nhị phân có độ dài cố định.
VARBINARY: Dãy nhị phân có độ dài biến đổi.
Boolean Type:

BIT: Giá trị logic (0 hoặc 1).
Other Types:

MONEY: Số tiền.
UNIQUEIDENTIFIER: Định danh duy nhất (GUID).
XML: Dữ liệu XML.
2.
Các system datatype được SQL Server lưu trữ trong bảng sys.types và 
thuộc cơ sở dữ liệu master. Bảng sys.types này là một trong các bảng 
system catalog (catalog system) được SQL Server sử dụng để lưu trữ thông 
tin về cơ sở dữ liệu và các đối tượng trong đó, bao gồm cả các loại dữ liệu
(datatype) cơ bản và người dùng tự định nghĩa.
3.
Các User-defined datatype (UDT) trong SQL Server được lưu trữ trong bảng sys.types và cơ sở dữ liệu trong đó chúng được tạo ra. 
Mỗi UDT sẽ nằm trong schema của cơ sở dữ liệu đó và có một bản ghi tương ứng trong bảng sys.types.

Ví dụ, nếu tạo một UDT trong cơ sở dữ liệu "MyDatabase" và đặt tên là "MyUDT," thì thông tin về UDT 
này sẽ được lưu trữ trong bảng sys.types của cơ sở dữ liệu "MyDatabase." 
Bạn có thể truy vấn bảng sys.types trong cơ sở dữ liệu đó để xem chi 
tiết về các UDT đã được tạo.
*/
--b.--
use QLBH
exec sp_addtype MaVung,'char(10)'
exec sp_addtype STT,'smallint'
exec sp_addtype SoDienThoai,'char(13)',NULL
exec sp_addtype Shortstring,'varchar(15)'
--c.--
/*Thông tin về các UDT được lưu trữ trong cơ sở dữ liệu (database) mà
đã sử dụng để định nghĩa chúng. Mỗi UDT sẽ nằm trong schema của cơ sở 
dữ liệu đó.
Các UDT có phạm vi sử dụng chỉ trong phạm vi của cơ sở dữ liệu (database) 
trong đó chúng được tạo ra. Điều này có nghĩa rằng chỉ có thể sử dụng 
các UDT trong cơ sở dữ liệu hiện hành mà đã định nghĩa chúng.
*/
--d.--
SELECT domain_name, data_type, character_maximum_length
FROM information_schema.domains
ORDER BY domain_name
--e.--
Em có thể tạo được.
--f.--
/*Để một User-Defined datatype (UDT) có thể được sử dụng trong tất cả các 
cơ sở dữ liệu (databases) trong SQL Server, cần định nghĩa nó ở mức 
instance, không phải ở một cơ sở dữ liệu cụ thể. Điều này có thể được thực 
hiện thông qua dịch vụ UDT trong SQL Server. 
*/
--g.--
exec sp_droptype SoDienThoai
