public with sharing class ExplainQueryController {

    private String instance;
    transient public String soql { get; set; }
    transient public String retJSON { get; set; }
    transient public String explain { get; set; }
    transient public String error { get; set; }
    
    public List<Plan> plans { get; set; }
    public Plan getLeadingPlan(){
        if(plans == null || plans.isEmpty())
            return null;
        else
            return plans[0];
    }

    //determine what URL prefix we're removing, c for unmanaged, soql-explain for managed.
    @testVisible
    private static String currentPrefix{
        get{
            if(currentPrefix == null){
                String prefix = ExplainQueryController.class.getName().substringBefore('ExplainQueryController');
                if(prefix.endsWith('.'))
                    prefix = prefix.removeEnd('.');
                if(String.isEmpty(prefix)){
                    return 'c';
                }else{
                    return prefix.replaceAll('_','-'); //underscores in namespaces are converted to hypens in domain names
                }
            }
            return currentPrefix;
        }
        set; //you really shouldn't set this unless it's for unit tests!
    }
    
    
    public ExplainQueryController() {
        //getting the API-enabled endpoint from a vf page URL is suprisingly tricky
        instance = deriveAPIEndpoint(URL.getSalesforceBaseUrl().getHost());
    }  

    /**
     * visualforce domains aren't API-enabled, so we need to figure out what the proper endpoint
     * retrieve the instance used to create endpoint URL
    **/
    @testVisible
    private static String deriveAPIEndpoint(String instance){
        String result;
        // check for my domain
        if (instance.contains('--'+currentPrefix+'.') && !instance.startsWith(currentPrefix+'.')) {
            // 1st remove the prefix and then add in the my.salesforce.com domain
              instance = instance.replace('--'+currentPrefix+'.', '.');
              instance = instance.replace('.visual.force.com', '.my.salesforce.com');
        }else {
            // strip out the starting 'c.' values
            instance = instance.removeStart(currentPrefix+'.');
            instance = instance.replace('.visual.force.com', '.salesforce.com');
        }
        result = 'https://' + instance;
        return result;
    }  
    
    public PageReference showExplainPlan() {
        HTTPRequest req = new HTTPRequest();
        req.setHeader('Authorization','Bearer ' + UserInfo.getSessionID());
        req.setHeader('Content-Type','application/json');
        
        req.setEndpoint(instance + '/services/data/v33.0/query/?explain=' + EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        
        Http h = new Http();
        HttpResponse res = h.send(req);
        String status = res.getStatus();
        Integer statusCode = res.getStatusCode();
        retJSON = res.getBody();
        
        plans = new List<Plan>();
        String text = '';
      
        // check if we had an error
        if (statusCode != 200) {
            for(ExplainErrorResponse error : (List<ExplainErrorResponse>) JSON.deserialize(retJSON, List<ExplainErrorResponse>.class)){ 
                String err = error.errorCode +' '+ error.message;
                
                ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.ERROR, status + ' - ' + err);
                ApexPages.addMessage(msg);
            }
        }
        else {           
            ExplainResponse response = (ExplainResponse) JSON.deserialize(retJSON, ExplainResponse.class);
            plans = response.plans;     
        }    
               
        return null;
    }

    public class ExplainErrorResponse{
        String errorCode {get; set;}
        String message {get; set;}
    }
    
    public class ExplainResponse{
        public List<Plan> plans {get; set;}
    }
    public class PlanNote{
        public String description { get; set; }
        public List<String> fields { get; set; }
        public String tableEnumOrId { get; set;}

        public String getCSVFields(){
            return String.join(fields, ', ');
        }
    }
    
    public class Plan {
        public Double cardinality { get; set; }
        public List<String> fields { get; set; }
        public String leadingOperationType { get; set; }
        public Double relativeCost { get; set; }
        public Double sObjectCardinality { get; set; }
        public String sObjectType { get; set;}
        public List<PlanNote> notes {get; set;}
    }
        
}