using System;
using System.Text;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.IO;
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
    public class GraphAPIClient
    {
        private static readonly HttpClient client = new HttpClient();

        public string token_type { get; set; }
        public string expires_in { get; set; }
        public string ext_expires_in { get; set; }
        public string access_token { get; set; }

        public async Task<GraphAPIClient> NewAccessToken(ILogger log)
        {
            
            Dictionary<string, string> ReqTokenBody = new Dictionary <string, string>
            {
                { "Grant_Type", "client_credentials" },
                { "Scope", "https://graph.microsoft.com/.default" },
                { "client_Id", System.Environment.GetEnvironmentVariable("AAD_APP_ID") },
                { "client_Secret", System.Environment.GetEnvironmentVariable("AAD_APP_SECRET") }
            };
            var content = new FormUrlEncodedContent(ReqTokenBody);
            log.LogInformation("Requesting access token");
            var response = await client.PostAsync($"https://login.microsoftonline.com/cookadamcouk.onmicrosoft.com/oauth2/v2.0/token", content);
            response.EnsureSuccessStatusCode();
            var responseString = await response.Content.ReadAsStringAsync();
            return JsonConvert.DeserializeObject<GraphAPIClient>(responseString);
        }

        public async Task<HttpResponseMessage> SendData(
            ILogger log,
            string method, 
            string url, 
            string body = "{}"
        )
        {
            log.LogInformation($"Sending '{method}' request to Graph '{url}'");

            if (body != "{}")
            {
                log.LogInformation($"Body: {body}");
            }

            var content = new StringContent(body, Encoding.UTF8, "application/json");
            HttpResponseMessage response = new HttpResponseMessage();
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", this.access_token);

            switch (method)
            {
                case "POST":
                    response = await client.PostAsync(url, content);
                    break;
                case "PATCH":
                    response = await client.PatchAsync(url, content);
                    break;
            }
            
            return response;
        }

    }
}