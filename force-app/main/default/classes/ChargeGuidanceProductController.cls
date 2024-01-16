public class ChargeGuidanceProductController {
    public static final String GUIDANCE_PRODUCT_NAME = 'Guidance on HMRC Reply';
    public static final String ADVICE_PRODUCT_NAME = 'Pension & Tax Advice';

    @AuraEnabled(cacheable = true)
    public static ApplicationData getApplication (String recordId) {
        ApplicationData resultData = new ApplicationData();
        List<Application__c> applications = [
            SELECT
                HMRC_Reply_Status__c,
                Status__c,
                Package_Name__c,
                Live_In_The_EU__c
            FROM Application__c
            WHERE Id = :recordId
        ];
        List<Payment__c> payments = [
            SELECT
                Name,
                Product__r.Name,
                Status__c,
                Amount__c
            FROM Payment__c
            WHERE Application__c = :recordId AND
                 (Product__r.Name = :GUIDANCE_PRODUCT_NAME OR
                    Product__r.Name = :ADVICE_PRODUCT_NAME)
        ];
        if (!applications.isEmpty()) {
            resultData.application = applications[0];
        }
        if (!payments.isEmpty()) {
            resultData.payments = payments;
        }
        return resultData;
    }

    @AuraEnabled
    public static ChargeResult chargeProduct(String recordId) {
        ChargeResult result = new ChargeResult();
        List<Payment__c> applicationPayment = [
            SELECT
                Name,
                Product__r.Name,
                Status__c,
                Payment_Date__c,
                Customer_Id__c,
                Payment_Method__c,
                Application__r.Status__c,
                Application__r.Package_Name__c,
                Application__r.HMRC_Reply_Status__c,
                Amount__c,
                Application__r.Email__c,
                Tax_VAT__c
            FROM Payment__c
            WHERE (Product__r.Name = :GUIDANCE_PRODUCT_NAME OR
                  Product__r.Name = :ADVICE_PRODUCT_NAME) AND
                  Application__c = :recordId
        ];
        Map<String, Payment__c> productNameByPayment = new Map<String, Payment__c>();
        for (Payment__c payment : applicationPayment) {
            productNameByPayment.put(payment.Product__r.Name, payment);
        }
        Payment__c currentPayment = applicationPayment[0];
        if (currentPayment.Application__r.Package_Name__c == 'Basic') {
            result.title   = 'Error';
            result.message = 'You cannot pay for a Guidance on HMRC Reply product for a Basic package!';
            result.variant = 'error';
            return result;
        }
        try {
            List<Payment__c> payments = new List<Payment__c>();
            if (currentPayment.Application__r.Status__c == 'Check & Charge') {
                payments.add(productNameByPayment.get(GUIDANCE_PRODUCT_NAME));
            } else if (currentPayment.Application__r.Status__c == 'Tax Call (Prem)') {
                payments.add(productNameByPayment.get(ADVICE_PRODUCT_NAME));
            }
            if (payments.isEmpty()) {
                result.message = 'You don\'t have nessesary product';
                result.variant = 'error';
                return result;
            }
            ApplicationService service = new ApplicationService();
            service.executeStripePayment(payments);
            result.title   = 'Success';
            result.message = 'You charge Guidance Product';
            result.variant = 'success';
            return result;
        } catch (Exception ex) {
            result.title   = 'Error';
            result.message = 'You didn\'t generate pdf files. Error is ' + ex.getMessage();
            result.variant = 'error';
            return result;
        }
    }

    public class ChargeResult {
        @AuraEnabled
        public String title {get; set;}
        @AuraEnabled
        public String message {get; set;}
        @AuraEnabled
        public String variant {get; set;}
    }

    public class ApplicationData {
        @AuraEnabled
        public Application__c application {get; set;}
        @AuraEnabled
        public List<Payment__c> payments {get; set;}
    }
}