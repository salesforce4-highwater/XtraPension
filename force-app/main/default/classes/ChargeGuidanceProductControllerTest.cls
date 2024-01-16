@isTest
public class ChargeGuidanceProductControllerTest {

    @TestSetup static void makeData() {
        List<Product2> products = TestDataFactory.createProductsWithPrices();
        Account account = TestDataFactory.createAccount(true);
        List<Contact> currentContact = [
            SELECT
                Id,
                AccountId
            FROM Contact
            WHERE AccountId = :account.Id
            LIMIT 1
        ];
        Id personContactId = currentContact[0].Id;
        Application__c application =  TestDataFactory.createApplication(personContactId, true);
        Order order = TestDataFactory.createOrder(application.Id, account.Id, true);
        TestDataFactory.createRelatedPaymentToApplication(products, application, order.Id, true);
    }

    @IsTest static void getApplicationTest() {
        List<Application__c> testApps = [
            SELECT Id
            FROM Application__c
            LIMIT 1
        ];
        Test.startTest();
        ChargeGuidanceProductController.ApplicationData resultData = ChargeGuidanceProductController.getApplication(testApps[0].Id);
        Test.stopTest();
        System.assertNotEquals(null, resultData.application, 'Don\'t exist new Application');
        System.assertEquals(false, resultData.payments.isEmpty(), 'Don\'t exist required Payments');
        System.assertEquals(2, resultData.payments.size(), 'Don\'t contains all nessasary Payments');
    }

    @IsTest static void chargeProductCase1Test() {
        List<Application__c> testApps = [
            SELECT Package_Name__c
            FROM Application__c
            LIMIT 1
        ];
        Application__c currentApplcation = testApps[0];
        currentApplcation.Package_Name__c = 'Basic';
        update currentApplcation;
        Test.startTest();
        ChargeGuidanceProductController.ChargeResult result = ChargeGuidanceProductController.chargeProduct(currentApplcation.Id);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Response don\'t contains result');
        System.assertEquals('Error', result.title, 'Result\'s Title is wrong');
        System.assertEquals('You cannot pay for a Guidance on HMRC Reply product for a Basic package!', result.message, 'Result\'s Message is wrong');
        System.assertEquals('error', result.variant, 'Result\'s Variant is wrong');
    }

    @IsTest static void chargeProductCase2Test() {
        Test.setMock(HttpCalloutMock.class, new PaymentServiceMock());
        List<Application__c> testApps = [
            SELECT
                Package_Name__c,
                Status__c
            FROM Application__c
            LIMIT 1
        ];
        Application__c currentApplcation = testApps[0];
        currentApplcation.Package_Name__c = 'Premier';
        currentApplcation.Status__c       = 'Check & Charge';
        update currentApplcation;
        Test.startTest();
        ChargeGuidanceProductController.ChargeResult result = ChargeGuidanceProductController.chargeProduct(currentApplcation.Id);
        Test.stopTest();
    }

    @IsTest static void chargeProductCase3Test() {
        Test.setMock(HttpCalloutMock.class, new PaymentServiceMock());
        List<Application__c> testApps = [
            SELECT
                Package_Name__c,
                Status__c
            FROM Application__c
            LIMIT 1
        ];
        Application__c currentApplcation = testApps[0];
        currentApplcation.Package_Name__c = 'Premier';
        currentApplcation.Status__c       = 'Tax Call (Prem)';
        update currentApplcation;
        Test.startTest();
        ChargeGuidanceProductController.ChargeResult result = ChargeGuidanceProductController.chargeProduct(currentApplcation.Id);
        Test.stopTest();
    }
}