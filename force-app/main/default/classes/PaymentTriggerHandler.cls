public class PaymentTriggerHandler {
    public static final String ORG_WIDE_EMAIL_ADDRESS = 'clients@xtrapension.com';
    public static final String EMAIL_TEMPLATE_NAME    = 'Client Receipt';
    public static final String ADMIN_EMAIL_ADDRESS  = 'jr@xtrapension.com';

    public static void sendEmailAfterChangeStatus(Map<Id, Payment__c> newPayments, Map<Id, Payment__c> oldPayments) {
        List<Payment__c> paidPayments = new List<Payment__c>();
        for (Payment__c payment : newPayments.values()) {
            if (payment.Status__c == 'Paid' && payment.Status__c != oldPayments.get(payment.Id).Status__c) {
                paidPayments.add(payment);
            }
        }
        if (!paidPayments.isEmpty()) {
            sendReceipt(paidPayments);
        }
    }

    public static void sendEmailAfterCreatePaidPayment(Map<Id, Payment__c> newPayments) {
        List<Payment__c> paidPayments = new List<Payment__c>();
        for (Payment__c payment : newPayments.values()) {
            if (payment.Status__c == 'Paid') {
                paidPayments.add(payment);
                sendRegistrationFeeDataToAdmin(payment);
                StripeApiService.updatePaymentCardData(payment.Id);
            }
        }
    }

    public static void sendReceipt(List<Payment__c> paidPayments) {
        Map<Id, Receipt__c> newReceipts = new Map<Id, Receipt__c>();
        for (Payment__c payment : paidPayments) {
            newReceipts.put(
                payment.Id,
                new Receipt__c(
                    Payment__c        = payment.Id,
                    Paid_Date__c      = payment.Payment_Date__c,
                    Payment_Method__c = payment.Card_Data__c,
                    Tax_EU__c         = payment.Tax_VAT__c,
                    Application__c    = payment.Application__c
                )
            );
        }
        if (newReceipts.isEmpty()) {
            return;
        }
        insert newReceipts.values();
        List<Receipt__c> currentReceipts = [
            SELECT
                Id,
                Application_Contact__c,
                Contact_Email__c,
                Application__c
            FROM Receipt__c
            WHERE Id IN :newReceipts.values()
        ];
        if (currentReceipts.isEmpty()) {
            return;
        }
        for (Receipt__c receipt : currentReceipts) {
            if(receipt.Id != null) {
                sendEmail(receipt);
            }
        }
    }

    private static void sendEmail(Receipt__c currentReceipt) {
        OrgWideEmailAddress[] owea = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE Address = :ORG_WIDE_EMAIL_ADDRESS
        ];
        List<EmailTemplate> receiptEmailTemplate = [
            SELECT
                Id
            FROM EmailTemplate
            WHERE Name = :EMAIL_TEMPLATE_NAME
        ];

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setTargetObjectId(currentReceipt.Application_Contact__c);
        message.setUseSignature(false);
        message.setBccSender(false);
        message.setSaveAsActivity(true);
        message.setTreatTargetObjectAsRecipient(false);
        if (!receiptEmailTemplate.isEmpty()) {
            message.setTemplateID(receiptEmailTemplate[0].Id);
        }
        message.setWhatId(currentReceipt.Id);
        if ( owea.size() > 0 ) {
            message.setOrgWideEmailAddressId(owea.get(0).Id);
        }
        message.toAddresses = new String[] { currentReceipt.Contact_Email__c };
        Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage> {message};
        Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);

        List<EmailMessage> relatedMessages = [
            SELECT
                HtmlBody,
                FromAddress,
                ToAddress,
                Subject
            FROM EmailMessage
            WHERE RelatedToId = :currentReceipt.Id
            ORDER BY CreatedDate DESC
        ];
        if (relatedMessages.isEmpty()) {
            return;
        }
        EmailMessage receiptMessage = relatedMessages[0];
        EmailMessage emailMessage = new EmailMessage();
        emailMessage.status       = '3';
        emailMessage.relatedToId  = currentReceipt.Application__c;
        emailMessage.fromAddress  = receiptMessage.FromAddress;
        emailMessage.ToAddress    = receiptMessage.ToAddress;
        emailMessage.Subject      = receiptMessage.Subject;
        emailMessage.HtmlBody     = receiptMessage.HtmlBody;
        insert emailMessage;
    }

    private static void sendRegistrationFeeDataToAdmin(Payment__c payment) {
        OrgWideEmailAddress[] owea = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE Address = :ORG_WIDE_EMAIL_ADDRESS
        ];
        List<Application__c> applications = [
            SELECT
                First_Name__c,
                Second_Name__c,
                Related_Contact_Phone__c,
                Email__c,
                Contact__c,
                Contact__r.MailingCountry,
                Current_Address_Abroad_Country__c
            FROM Application__c
            WHERE Id = :payment.Application__c
        ];
        if (applications.isEmpty()) {
            return;
        }
        Application__c currentApplication = applications[0];
        String htmlBody =
            '<div>Client email address ' + currentApplication.Email__c + '</div>' +
            '<div>Tel  '+ currentApplication.Related_Contact_Phone__c +'</div>';
        String subject = '€' + payment.Amount__c + ' sale - ('+
                               currentApplication.First_Name__c + ' ' +
                               currentApplication.Second_Name__c +') - ' +
                               CountryCodeHelper.getCountryNameByIsoCode(currentApplication.Contact__r.MailingCountry);
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setUseSignature(false);
        message.setBccSender(false);
        message.setSaveAsActivity(true);
        message.setTreatTargetObjectAsRecipient(false);
        message.setWhatId(currentApplication.Id);
        message.setSubject(subject);
        message.setHtmlBody(htmlBody);
        if ( owea.size() > 0 ) {
            message.setOrgWideEmailAddressId(owea.get(0).Id);
        }
        message.toAddresses = new String[] { ADMIN_EMAIL_ADDRESS };
        Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage> {message};
        Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
    }
}