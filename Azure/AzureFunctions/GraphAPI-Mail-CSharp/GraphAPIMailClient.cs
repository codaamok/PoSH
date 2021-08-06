using System;
using System.Text;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.IO;
using System.Threading.Tasks;
using System.Reflection;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Newtonsoft.Json.Serialization;

namespace GraphAPI_Mail_CSharp
{
    public class GraphAPIMailClient
    {
        
        public string id { get; set; }
        public GraphAPIClient accessToken { get; set; }
        public string subject { get; set; }
        public string content { get; set; }
        public Dictionary<string, string> toRecipients { get; set; }
        public Dictionary<string, string> replyToRecipients { get; set; }
        public string user { get; set; }

        public GraphAPIMailClient (string subject, string content, Dictionary<string, string> toRecipients, string user) {
            this.subject = subject;
            this.content = content;
            this.toRecipients = toRecipients;
            this.user = user;
        }

        private class Mail
        {
            public string subject { get; set; }
            public string importance { get; set; }
            public Mail_Body body { get; set; }
            public List<Mail_Recipient> toRecipients { get; set; }            
            public List<Mail_Recipient> replyTo { get; set; }

            public Mail (string subject = null, string content = null, Dictionary<string, string> toRecipients = null, Dictionary<string, string> replyToRecipients = null )
            {
                if (toRecipients != null)
                {
                    List<Mail_Recipient> recipients = new List<Mail_Recipient>();

                    foreach(string recipient in toRecipients.Keys)
                    {
                        recipients.Add(new Mail_Recipient(
                            address: recipient, 
                            name: toRecipients[recipient]
                        ));
                    }

                    this.toRecipients = recipients;
                }

                if (replyToRecipients != null)
                {
                    List<Mail_Recipient> recipients = new List<Mail_Recipient>();

                    foreach(string recipient in replyToRecipients.Keys)
                    {
                        recipients.Add(new Mail_Recipient(
                            address: recipient, 
                            name: replyToRecipients[recipient]
                        ));
                    }

                    this.replyTo = recipients;
                }

                if (content != null)
                {
                    this.body = new Mail_Body(contentType: "HTML", content: content);
                }

                if (subject != null) 
                {
                    this.subject = subject;
                }

                this.importance = "low";
            }
        }

        private class Mail_Body 
        {
            public string contentType { get; set; }
            public string content { get; set; }
            
            public Mail_Body (string contentType, string content) {
                this.contentType = contentType;
                this.content = content;
            }
        }

        private class Mail_Recipient 
        {
            public Mail_RecipientProperties emailAddress { get; set; } 

            public Mail_Recipient (string address, string name )
            {
                this.emailAddress = new Mail_RecipientProperties(
                    address: address, 
                    name: name
                );
            }
        }

        private class Mail_RecipientProperties 
        {
            public string address { get; set; }
            public string name { get; set; }
            public Mail_RecipientProperties (string address, string name)
            {
                this.address = address;
                this.name = name;
            }
        }

        public class IgnorePropertiesResolver : DefaultContractResolver
        {
            private readonly HashSet<string> ignoreProps;
            public IgnorePropertiesResolver(IEnumerable<string> propNamesToIgnore)
            {
                this.ignoreProps = new HashSet<string>(propNamesToIgnore);
            }

            protected override JsonProperty CreateProperty(MemberInfo member, MemberSerialization memberSerialization)
            {
                JsonProperty property = base.CreateProperty(member, memberSerialization);
                if (this.ignoreProps.Contains(property.PropertyName))
                {
                    property.ShouldSerialize = _ => false;
                }
                return property;
            }
        }
        
        public async Task CreateDraft (ILogger log)
        {
            log.LogInformation("Creating message");
            GraphAPIClient GraphAPIClient = new GraphAPIClient();
            GraphAPIClient = await GraphAPIClient.NewAccessToken(log);
            this.accessToken = GraphAPIClient;
            
            var url = $"https://graph.microsoft.com/v1.0/users/{user}/messages";
            Mail body = new Mail (subject: subject, content: content, toRecipients: toRecipients);

            string json = JsonConvert.SerializeObject(
                body, 
                new JsonSerializerSettings()
                { 
                    ContractResolver = new IgnorePropertiesResolver(
                        new[] { "replyTo" }
                    )
                }
            );
            
            HttpResponseMessage result = new HttpResponseMessage();
            result = await GraphAPIClient.SendData(log, "POST", url, json);
            result.EnsureSuccessStatusCode();
            log.LogInformation("Success");

            Match m = Regex.Match(result.Headers.Location.Segments[3], @"^messages\('(.+)'\)$");
            this.id = m.Groups[1].Value;
            log.LogInformation($"Message ID: {this.id}");
        }

        public async Task UpdateMessage (ILogger log, Dictionary<string, string> replyToRecipients)
        {
            log.LogInformation("Updating message");

            var url = $"https://graph.microsoft.com/v1.0/users/{this.user}/messages/{this.id}";
            Mail body = new Mail (replyToRecipients: replyToRecipients);

            string json = JsonConvert.SerializeObject(
                body, 
                new JsonSerializerSettings()
                { 
                    ContractResolver = new IgnorePropertiesResolver(
                        new[] { "subject", "content", "toRecipients", "body" }
                    )
                }
            );

            HttpResponseMessage result = new HttpResponseMessage();
            result = await accessToken.SendData(log, "PATCH", url, json);
            result.EnsureSuccessStatusCode();
            log.LogInformation("Success");
        }

        public async Task SendMessage (ILogger log)            
        {
            log.LogInformation("Sending message");
            var url = $"https://graph.microsoft.com/v1.0/users/{this.user}/messages/{this.id}/send";
            HttpResponseMessage result = new HttpResponseMessage();
            result = await accessToken.SendData(log, "POST", url);
            result.EnsureSuccessStatusCode();
            log.LogInformation("Success");
        }
    }
}