---
layout: post
title: "Jenkins EnvVar Templating"
date:  2015-04-27 12:00:00:00
---

I've been doing a bit of Jenkins plugin development lately and I have
found that documentation can be a bit scarce. Like many projects out
there, they show you how to drive a nail and then expect you to go off
and build a house. I'm posting a little bit of what I have created in
hopes of either sharing some much needed documentation or being shown
a better way to do things.

While building my plugin I needed a way to inject Jenkins environment
variables, called `EnvVars` in Jenkins API into some input. Not being
able to find any built-in utilities to do this, I wrote my own. So,
without further to-do, a util that has been useful (for met at least):

{% highlight java linenos %}
import hudson.EnvVars;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class EnvTemplater {

    private static final Pattern VARIABLE_PATTERN = Pattern.compile(
            "(\\$\\{?[A-Za-z_]+\\}?)");
    private static final Pattern VARIABLE_NAME_PATTERN = Pattern.compile("([A-Za-z_]+)");

    /**
     * Given an input string, find environment var patterns and inject them into
     * the string from the current environment variables. The input of the string really
     * isn't important to this function, only the format of the variables within the string.
     * We look for two forms of variables:
     *  - $VAR_NAME
     *  - ${VAR_NAME}
     *
     * Note: The environment variables that we are using are not _true_ environment 
     * variables, but rather Jenkins Environment variables (the same ones you would normally 
     * use to template within a normal Jenkins job).
     *
     * @param input The input string to be templated (possibly containing variable 
     *              expressions)
     * @param vars  The vars to use to inject into the input string
     * @return      A string where the variables have been replaced by Jenkins evn variable 
     *              value, if the variable exists.
     */
    public static String templateString(String input, EnvVars vars) {
        if (vars == null || input == null) {
            return input;
        }

        String output = input;
        Matcher match = VARIABLE_PATTERN.matcher(input);
        int replacementOffset = 0;

        // iterate through all of the variables that we find
        while (match.find()) {

            // find the variable name (without the $ and {} characters)
            String matchGroup = match.group();
            Matcher varNameMatcher = VARIABLE_NAME_PATTERN.matcher(matchGroup);
            while (varNameMatcher.find()) {
                // pull out variable name, replace using bounds of outer `match`
                String varNameMatchGroup = varNameMatcher.group(1);
                int startPos = match.start(1);
                int endPos = match.end(1);
                if (vars.containsKey(varNameMatchGroup)) {
                    String replacement = vars.get(varNameMatchGroup, matchGroup);
                    output = output.substring(0, replacementOffset + startPos)
                            + replacement
                            + output.substring(replacementOffset + endPos, output.length());

                    // replacement offset is used during string replacement to account for 
                    // the string growing or shrinking as we replace values (and the regex 
                    // positions being out of date).
                    replacementOffset +=  replacement.length() - (endPos - startPos);
                }
            }
        }
        return output;
    }
}
{% endhighlight %}
