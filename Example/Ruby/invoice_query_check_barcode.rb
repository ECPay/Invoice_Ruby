require 'ecpay_invoice'


	# 手機條碼驗證
		## 參數值為[PLEASE MODIFY]者，請每次測試時給予獨特值
		query_check_barcode_dict = {
			"BarCode"=>"/......." # 手機條碼，長度為7字元
		}
		
		query_check_barcode = ECpayInvoice::QueryClientECPay.new # 將模組中的class實例化
		res = query_check_barcode.ecpay_query_check_mob_barcode(query_check_barcode_dict) # 對class中的對應的method傳入位置參數
		
	puts res # 將回傳結果列印出來
