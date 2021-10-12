# Ruby on Rails API with KeyCloak Integration



This is a walkthrough/note-to-self on how to set-up a basic environment with Ruby On Rails and Keycloak for offloading the user authentication and authorization to a centralized server when working with multiple services. This way, Rails API acts only as a resource server and is not responsible for the user auth flow. 

Rails will receive a token issued by Keycloak and will validate it, ensuring the user is authenticated against Keycloak and the token is not expired.

```mermaid
sequenceDiagram
    Browser->>KeyCloak: Hello. I'm John, let me in.
    KeyCloak-->>Browser: Ok! I can see you're John. Here's your key.
    Browser->>Rails API: I'm John! Use this key and give me the info I want.
    Rails API-)Rails API: ** sniffing the fresh token **
    Rails API-->>Browser: Ok, the key fits the locker. Here's your new messages.
    Browser->>Rails API: Oh, I also want to delete the message with id 7
    Rails API-)Rails API: Hmm, I can't see the permission here.
    Rails API-->>Browser: Nope. You can't do that. You will need to ask your papa.

```

<br/>
<br/>
By using JWT claims, we can also check for user permission and decide if we want them to have access to the resource.
<br/>
<br/>
<br/>

```mermaid
sequenceDiagram
    Browser->>KeyCloak: Hello. I'm John's papa, let me in.
    KeyCloak-->>Browser: Howdy Mr. Papa. Here's your key.
    Browser->>Rails API: Please delete the message with id 7, now!
    Rails API-)Rails API: ** sniffing the fresh token **
    Rails API -)Rails API: Oh, ok, he's telling he's the boss!
    Rails API-->>Browser: Sure, Mr. Papa. It has been deleted. 

```


<br/>

Now we're able to implement a microservices architecture with ease as the authentication is now running on the KeyCloak and the rails resource server is only another client among the others. This approch will also enable us to do a granular control over the things that a user can or cannot access. We can divide the users in groups, roles, and even create custom attributes to enable/disable some features in our code.


<br/>

___

<br/>

## Running Keycloak and PostgreSQL

Keycloak, PostgreSQL and PGAdmin infrastructure is provided as a Docker Compose file. To set everything, just run the command:

```bash
docker-compose up
``` 
Of course, I'm assuming you have all the dependencies for docker installed.

After keycloak is running, you can access the admin console using the address: `http://localhost:9080/auth/`

Import the provided realm config or configure it on your own. We'll be using a confidential client for the backend API. 

You can test the user login on the page: `http://localhost:9080/auth/realms/demo-app/account/`, using the username as `user1` and the password `user@1`.

<br/>

___

<br/>

## Scaffolding the Rails API

Create the project and the resources you want to test the authentication/authorization against. 

In this example, there is only the `notification` resource. Also, I decided to implement the logic to validate the JSON directly on the Application Controller. You may want to create another controller if you have routes that can be accessed without the authentication.

The source code of the application controller I used to test this code is as following:

```ruby
class ApplicationController < ActionController::API
    before_action :require_jwt
  
    def require_jwt
      token = request.headers["HTTP_AUTHORIZATION"]
      if !token
        head :forbidden
      end
      if !valid_token(token)
        head :forbidden
      end
    end

    def is_papa
      token = request.headers["HTTP_AUTHORIZATION"]

      begin
        rsa_key = create_cert
        decoded_token = JWT.decode(token, rsa_key.public_key, true, { algorithm: "RS256" })
        groups = decoded_token[0]["groups"]  
        return groups.include? "/papas"
      rescue JWT::DecodeError
        Rails.logger.warn "Error decoding the JWT"
      end
    end
  
    private

    def create_cert
    public_key = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqciCym8vkFScUVZoQ/CG4bE7CUZ6KdADCJO3qj6sJkFi+Dlu37dPx3/Q2l90n+dYsFHu/XAW07PcBVUuFjlt8KMbJCfekbcaKk+SsGoVE5H0ZJSb41pPqDHh2oV+ucjdZ+Ce9BY2IzlcbUAgX7go6p3X6XuEUGkQuU83aTGf2z0Msit3rGf3gz3QVcKKBFL2Lj8ZE3U/e/o9AgtejHWxnQotWTn7fa98bIk0YFGD+Uip1N0cmFfXIGnA+5xcwTgljp9XZYtE26RVEer0KCpK7gVRSIAshhAtqIH8I10buxnOqTNui1a1G7Aj3t0TdQDAt/8qnaTqDLtNjBIdlZSG3wIDAQAB"
    rsa_pub_key = "-----BEGIN PUBLIC KEY-----\n" + public_key + "\n-----END PUBLIC KEY-----"
    rsa_key = OpenSSL::PKey::RSA.new rsa_pub_key
    end

    def valid_token(token)
      unless token
        return false
      end

      token.gsub!('Bearer ','')

      begin
        rsa_key = create_cert
        decoded_token = JWT.decode(token, rsa_key.public_key, true, { algorithm: "RS256" })
        return true
      rescue JWT::DecodeError
        Rails.logger.warn "Error decoding the JWT"
      end
      false
    end
  end
```

The `public_key` field is the RSA Public Key of the Keycloak instance. We use this public key to authenticate the issued token, so we don't need to ask keycloak if the session is valid everytime we're hit by a request.
You can obtain it on the section `Keys` on the realm. For example, in this demo, the public key corresponds to `Demo-App` realm.

The following lines are just a manipulation to transform the public key to a valid RSA key, so JWT lib can decode the token. In a real implementation, I should probably read the RSA Key from the file system or something like that. 

This way, we only need to run the Rails app and our resource is already protected!

```bash
rails db:migrate
rails s
```

<br/>

___

<br/>

## Testing the System

This is just a proof-of-concept, so ignore the tests already created by rails. I didn't update them. Let's test by hand!

After you run both the docker-compose and the rails server, now we need a token to test the authentication. You will need to replace with your own values, but for this example this could be obtained running:

```bash
curl --request POST \
  --url http://localhost:9080/auth/realms/demo-app/protocol/openid-connect/token \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --cookie AUTH_SESSION_ID=b6193ef5-9d1b-4ba8-8984-9510ef3ad86e.da2cba344800 \
  --data client_id=demo-api \
  --data grant_type=password \
  --data client_secret=cbe52e86-adb0-4acd-b796-155d18abd974 \
  --data username=user1 \
  --data password=user@1
```

You'll receive the access token, that you can use to request th data to Rails API:

```bash
curl --request GET \
  --url http://localhost:3000/notifications \
  --header 'Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJxblBYSnFuWlRQQUZJdUtDWG13UUVJbkRZUlliQ0otTGoxWXlxdlhveF9BIn0.eyJleHAiOjE2MzM5MDE4NDEsImlhdCI6MTYzMzkwMTU0MSwianRpIjoiNjBmZDg1YzktNGI2ZS00Zjk5LThhMjctMTAyMTg2NzA0OTI3IiwiaXNzIjoiaHR0cDovL2xvY2FsaG9zdDo5MDgwL2F1dGgvcmVhbG1zL2RlbW8tYXBwIiwiYXVkIjoiYWNjb3VudCIsInN1YiI6IjMyNTQ1MDZmLTYwMzUtNDZlMi1iOWViLTJhNTI4NjUxODFiZSIsInR5cCI6IkJlYXJlciIsImF6cCI6ImRlbW8tYXBpIiwic2Vzc2lvbl9zdGF0ZSI6IjdmYjdkN2YxLWFlZDItNDk2NC1iYjFjLWUwZWZlMjI5ZWEzMCIsImFjciI6IjEiLCJhbGxvd2VkLW9yaWdpbnMiOlsiaHR0cDovL2xvY2FsaG9zdDozMDAwIl0sInJlYWxtX2FjY2VzcyI6eyJyb2xlcyI6WyJvZmZsaW5lX2FjY2VzcyIsInVtYV9hdXRob3JpemF0aW9uIl19LCJyZXNvdXJjZV9hY2Nlc3MiOnsiYWNjb3VudCI6eyJyb2xlcyI6WyJtYW5hZ2UtYWNjb3VudCIsIm1hbmFnZS1hY2NvdW50LWxpbmtzIiwidmlldy1wcm9maWxlIl19fSwic2NvcGUiOiJlbWFpbCBwcm9maWxlIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsIm5hbWUiOiJ1c2VyIG9uZSIsInByZWZlcnJlZF91c2VybmFtZSI6InVzZXIxIiwiZ2l2ZW5fbmFtZSI6InVzZXIiLCJmYW1pbHlfbmFtZSI6Im9uZSIsImVtYWlsIjoidXNlcjFAdXNlci5jb20ifQ.BZfLNvNZtndBZLUI3x3x5xYS3DRxUz2mJqIR8VYEtv8ns_Dim4u5szqYuucSlrumlm3FU2dD2D1tXxBbytW4wJT4w5ZBLVgLhOW5d_dWcLGbFkFjy9DSYM8mLI-W5s-zMcVDRWAXtAIT6ZmQy9sbqI1kdd5dynMQxcWtRnP9WwiG7BjdKDSmmhZwYPJlJDS5L2q2JA8in9xAyoxF5XYWOLsokYsObSi1wwKUF0Tq0ujkGM307R5bZwlqNwUrTP3fxhu6loosEJvKFiCSO7ybh17jbJg9PWVu9UjY86ZGHQwEPWe84pIO4agNCyWxZ2X0cmMkq7d6Y3j3FdUZrGGT5A'
```

You must receive the list of notifications and a status code of 200.

To verify how the groups are passed to the token, you can edit the `destroy` method of your resource, e.g:
```ruby 
  ...
  # DELETE /notifications/1
  def destroy
    if is_papa ## Defined on App Controller.
      @notification.destroy
    else
      render status: :forbidden
    end
  end
  ...
```

Now, create a group names papas on your KeyCloak configuration and assign user2 to this new group. On the `demo-api` client, ensure you create a new user attribute mapper to access these groups into the JWT token.
Try to remove any item using the user1 and then using the user2. Only the second one should have the permission to complete the operation.

You can mix and match groups, roles, user attributes and etc to implement your user authorization the way it works better to you and your system!

<br/>

___

<br/>


## TODO !

Investigate the usage of keycloak-api-rails gem:
- https://github.com/looorent/keycloak-api-rails


<br/>

___

<br/>

## Utils: OmniAuth, Oauth2, JWT, etc

ToDo: Include links, organize links, clean-up everything that is not relevant

- https://fusionauth.io/blog/2020/06/11/building-protected-api-with-rails-and-jwt/
- https://fusionauth.io/blog/2020/12/14/how-to-securely-implement-oauth-rails/
- https://github.com/jwt/ruby-jwt
- https://lists.jboss.org/pipermail/keycloak-user/2018-October/015761.html -> Use of RS256 (not HS256)
- https://jwt.io/


- https://www.keycloak.org/docs/latest/getting_started/#creating-a-realm-and-a-user


- https://www.honeybadger.io/blog/oauth2-ruby/
- https://github.com/oauth-xx/oauth2
- https://fusionauth.io/
- https://github.com/FusionAuth/fusionauth-example-rails-oauth
- https://www.sitepoint.com/rails-authentication-oauth-2-0-omniauth/
- https://developer.okta.com/blog/2021/07/20/rails-guide-securing-api
- https://www.miniorange.com/ruby-on-rails-adfs-single-sign-on(sso)


- https://engineering.musefind.com/building-a-simple-token-based-authorization-api-with-rails-a5c181b83e02

- https://stackoverflow.com/questions/32585792/implementing-single-sign-on-with-keycloak

- https://medium.com/binar-academy/rails-api-jwt-authentication-a04503ea3248





