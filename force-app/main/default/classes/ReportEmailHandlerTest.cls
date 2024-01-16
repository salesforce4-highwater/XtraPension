@isTest
public class ReportEmailHandlerTest {

    @IsTest(SeeAllData='true')
    static void myTestMethod1() {
        Test.startTest();
        ReportEmailHandler.sendReport();
        Test.stopTest();
        Integer invocations = Limits.getEmailInvocations();
        System.assertEquals(0, invocations, 'An email should be sent');
    }
}