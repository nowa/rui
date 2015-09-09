### RUI

rui可用于远程设置ROS。

* 支持管理IP地址列表，并同步到到ROS指定的Address List中；
	* 加入前要先检查是否已经存在；
	* 暂不考虑过期机制；
* 支持管理域名列表，并同步到Layer7 Protocols中；


上述功能都支持：

* 支持逐个或批量提交；
* 支持HTTP API接口，支持网页界面管理；

### API接口

##### 添加IP

* /address
	* POST
	* 参数：address，IP地址（支持掩码），必须项
	* 参数：comment，注释，可选项
	* 无返回
* /addresses
	* POST
	* 参数：addresses，IP地址列表（支持掩码），用换行符\n分隔，必须项
	* 参数：comment，注释，可选项
	* 无返回
	
##### 添加域名

* /domain
	* POST
	* 参数：domain，域名，必须项
	* 无返回
* /domains
	* POST
	* 参数：domains，域名列表，用“|”分隔，必须项
	* 无返回