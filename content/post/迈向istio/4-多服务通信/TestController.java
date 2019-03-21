package com.tanx.istio.demo;


import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;

import java.util.Collections;

@RestController
@RequestMapping
public class TestController {
    @Autowired
    private RestTemplate restTemplate;

    @RequestMapping("/proxy")
    public String proxy(@RequestHeader(value = "end-user", required = false) String user,
                        @RequestHeader(value = "x-request-id", required = false) String xreq,
                        @RequestHeader(value = "x-b3-traceid", required = false) String xtraceid,
                        @RequestHeader(value = "x-b3-spanid", required = false) String xspanid,
                        @RequestHeader(value = "x-b3-parentspanid", required = false) String xparentspanid,
                        @RequestHeader(value = "x-b3-sampled", required = false) String xsampled,
                        @RequestHeader(value = "x-b3-flags", required = false) String xflags,
                        @RequestHeader(value = "x-ot-span-context", required = false) String xotspan,
                        String url) {
	System.out.println("=============请求header============");
        System.out.println("end-user:"+user);
        System.out.println("x-request-id:"+xreq);
        System.out.println("x-b3-traceid:"+xtraceid);
        System.out.println("x-b3-spanid:"+xspanid);
        System.out.println("x-b3-parentspanid:"+xparentspanid);
        System.out.println("x-b3-sampled:"+xsampled);
        System.out.println("x-b3-flags:"+xflags);
        System.out.println("x-ot-span-context:"+xotspan);
        System.out.println("=============请求header============");

        System.out.println("=============请求url============");
        System.out.println(url);
        System.out.println("=============请求url============");
        HttpHeaders requestHeaders = new HttpHeaders();
        if (xreq != null) {
            requestHeaders.put("x-request-id", Collections.singletonList(xreq));
        }
        if (xtraceid != null) {
            requestHeaders.put("x-b3-traceid", Collections.singletonList(xtraceid));
        }
        if (xspanid != null) {
            requestHeaders.put("x-b3-spanid", Collections.singletonList(xspanid));
        }
        if (xparentspanid != null) {
            requestHeaders.put("x-b3-parentspanid", Collections.singletonList(xparentspanid));
        }
        if (xsampled != null) {
            requestHeaders.put("x-b3-sampled", Collections.singletonList(xsampled));
        }
        if (xflags != null) {
            requestHeaders.put("x-b3-flags", Collections.singletonList(xflags));
        }
        if (xotspan != null) {
            requestHeaders.put("x-ot-span-context", Collections.singletonList(xotspan));
        }
        if (user != null) {
            requestHeaders.put("end-user", Collections.singletonList(user));
        }

        ResponseEntity<String> exchange = restTemplate.exchange(url, HttpMethod.GET, new HttpEntity<>(requestHeaders), String.class);
        String body = exchange.getBody();
        System.out.println("代理返回内容为:" + body);
        return body;
    }

    @RequestMapping("index")
    public String index(@RequestHeader(value = "end-user", required = false) String user,
                        @RequestHeader(value = "x-request-id", required = false) String xreq,
                        @RequestHeader(value = "x-b3-traceid", required = false) String xtraceid,
                        @RequestHeader(value = "x-b3-spanid", required = false) String xspanid,
                        @RequestHeader(value = "x-b3-parentspanid", required = false) String xparentspanid,
                        @RequestHeader(value = "x-b3-sampled", required = false) String xsampled,
                        @RequestHeader(value = "x-b3-flags", required = false) String xflags,
                        @RequestHeader(value = "x-ot-span-context", required = false) String xotspan) {
	System.out.println("=============请求header============");
        System.out.println("end-user:"+user);
        System.out.println("x-request-id:"+xreq);
        System.out.println("x-b3-traceid:"+xtraceid);
        System.out.println("x-b3-spanid:"+xspanid);
        System.out.println("x-b3-parentspanid:"+xparentspanid);
        System.out.println("x-b3-sampled:"+xsampled);
        System.out.println("x-b3-flags:"+xflags);
        System.out.println("x-ot-span-context:"+xotspan);
        System.out.println("=============请求header============");

        return "index-java";
    }

}
