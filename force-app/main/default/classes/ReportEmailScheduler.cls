public class ReportEmailScheduler implements Schedulable {
    public void execute(SchedulableContext SC) {
        ReportEmailHandler.sendReport();
    }
}