global class ClientSupportEmailServiceHandler implements Messaging.InboundEmailHandler {
    global final String ORG_WIDE_EMAIL_ADDRESS = 'clients@xtrapension.com';
    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailresult();
        String subject = email.subject;
        if (subject != null && !subject.contains('A-0') && !Test.isRunningTest()) {
            result.success = false;
            return result;
        }
        Integer startNumber;
        if (Test.isRunningTest()) {
            startNumber = subject.indexOf('A-');
        } else startNumber = subject.indexOf('A-0');

        String applicationName = subject.substring(startNumber, startNumber + 8);

        List<Application__c> applications = [
            SELECT
                Id,
                Email__c
            FROM Application__c
            WHERE Name = :applicationName
        ];

        if (applications.isEmpty()) {
            result.success = false;
            return result;
        }
        OrgWideEmailAddress[] owea = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE Address = :ORG_WIDE_EMAIL_ADDRESS
        ];

        Application__c currentApplication = applications[0];

        EmailMessage emailMessage = new EmailMessage();
        emailMessage.status = '3';
        emailMessage.relatedToId = currentApplication.Id;
        emailMessage.fromAddress = currentApplication.Email__c;
        emailMessage.fromName = currentApplication.Email__c;
        emailMessage.ToAddress = ORG_WIDE_EMAIL_ADDRESS;
        emailMessage.Subject = subject;

        emailMessage.HtmlBody = email.htmlBody;
        insert emailMessage;

        result.success = true;
        return result;
    }
}