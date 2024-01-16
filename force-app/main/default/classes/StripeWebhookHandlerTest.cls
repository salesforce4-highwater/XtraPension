@isTest
public class StripeWebhookHandlerTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createProductsWithPrices();
        TestDataFactory.createTestCountry(true);
    }

    @IsTest static void invokeRestResponseTest() {
        Test.setMock(HttpCalloutMock.class, new CustomerDataMock());
        System.debug(Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
        .get('Business_Account')
        .getRecordTypeId());
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = '/StripeWebhookApi';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(
            '{ '+
                '"id": "evt_12457185",' +
                '"data": {' +
                    '"object": {'+
                        '"amount": 10000,' +
                        '"description": "Registration MOTO",' +
                        '"customer": "cus_9874054",' +
                        '"payment_method": "pm_784151245941124",' +
                        '"id":"pi_87541124578415",' +
                        '"shipping": {' +
                            '"address": {' +
                                '"city": "Galway",' +
                                '"country": "US",' +
                                '"line1": "73 West Street",' +
                                '"postal_code": "04075",' +
                                '"state": "ID"' +
                            '},' +
                            '"name": "Ugerd Lane",' +
                            '"phone": "+375297926917"' +
                        '}' +
                    '}' +
                '}' +
            '}');
        RestContext.request = request;
        RestContext.response= response;
        List<Application__c> testApplicationsBeforeRequest = [
            SELECT Id
            FROM Application__c
        ];
        System.assertEquals(0, testApplicationsBeforeRequest.size());
        Test.startTest();
            StripeWebhookHandler.invokeRestResponse();
        Test.stopTest();
        List<Application__c> testApplicationsAfterRequest = [
            SELECT
                Id,
                First_Name__c,
                Second_Name__c,
                Payment_Method__c,
                Stripe_Customer_Id__c,
                Stripe_Transaction_Id__c,
                Email__c,
                Related_Contact_Phone__c
            FROM Application__c
        ];
        System.assertEquals(1, testApplicationsAfterRequest.size());
        Application__c currentApplication = testApplicationsAfterRequest[0];
        System.assertEquals('Ugerd', currentApplication.First_Name__c);
        System.assertEquals('Lane', currentApplication.Second_Name__c);
        System.assertEquals('pm_784151245941124', currentApplication.Payment_Method__c);
        System.assertEquals('pi_87541124578415', currentApplication.Stripe_Transaction_Id__c);
        System.assertEquals('cus_9874054', currentApplication.Stripe_Customer_Id__c);
    }

    private class CustomerDataMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{' +
                    '"id":"cus_9874054", ' +
                    '"email":"john.snow@gmail.com"' +
                '}');
            res.setStatusCode(200);
            return res;
        }
    }
}