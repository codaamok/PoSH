using System;
using System.Text;
using System.Collections.Generic;
using System.Net.Http;
using System.IO;
using System.Web;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace GraphAPI_Mail_CSharp
{

    public static class GraphAPI_Mail
    {
        [FunctionName("GraphAPI_Mail")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", "post", Route = null)] HttpRequest req,
            ILogger log)
        {
            log.LogInformation("C# HTTP trigger function processed a request.");

            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();

            JObject data = JsonConvert.DeserializeObject<JObject>(requestBody);

            log.LogInformation("Printing POST'ed data");

            foreach (var item in data)
            {
                log.LogInformation($"- {item.Key}: {item.Value}");
            }

            GraphAPIMailClient mail = new GraphAPIMailClient(
                subject: "Hello world",
                content: "This is a message from GraphAPI-Mail-CSharp",
                toRecipients: new Dictionary<string, string> 
                { 
                    { System.Environment.GetEnvironmentVariable("AAD_USER"), "Joe Bloggs" }
                },
                user: System.Environment.GetEnvironmentVariable("AAD_USER")
            );

            try {
                await mail.CreateDraft(log);
            }
            catch (Exception ex) {
                log.LogError($"Failed to create message: {ex.Message.ToString()}");
            }

            // The below code just updates properties for the newly created draft
            // Leaving it in-place, but commented out, just for completeness as example code
            /*
            try {
                await mail.UpdateMessage(
                    log: log,
                    replyToRecipients: new Dictionary<string, string> 
                    { 
                        { data["senderEmailAddress"].ToString(), data["senderName"].ToString() }
                    }
                );
            }
            catch (Exception ex) {
                log.LogError($"Failed to update message: {ex.Message.ToString()}");
            }
            */

            try {
                await mail.SendMessage(log);
            }
            catch (Exception ex) {
                log.LogError($"Failed to send message: {ex.Message.ToString()}");
            }

            return new OkResult();
        }
    }
}
