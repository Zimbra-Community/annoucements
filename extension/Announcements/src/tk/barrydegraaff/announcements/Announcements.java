/*

Copyright (C) 2016  Barry de Graaff

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see http://www.gnu.org/licenses/.

*/
package tk.barrydegraaff.announcements;

import java.util.Map;

import com.zimbra.common.localconfig.LC;
import com.zimbra.common.service.ServiceException;
import com.zimbra.common.soap.Element;
import com.zimbra.common.soap.SoapParseException;
import com.zimbra.soap.DocumentHandler;
import com.zimbra.soap.ZimbraSoapContext;

import java.sql.*;
import java.io.*;
import java.text.*;
import java.util.*;


public class Announcements extends DocumentHandler {
    final String db_connect_string = this.getDbConnectionString();

    public Element handle(Element request, Map<String, Object> context)
            throws ServiceException {
        try {
            // Create response

            ZimbraSoapContext zsc = getZimbraSoapContext(context);

            Element response = zsc.createElement(
                    "AnnouncementsResponse"
            );
            //Element content = response.addUniqueElement("content");
            ////elStart.setText(request.getAttribute("user"));
            //content.setText(getAnnouncements(db_connect_string, response));
            //return response;
            return getAnnouncements(db_connect_string, response);

        } catch (
                Exception e)

        {
            throw ServiceException.FAILURE("exception occurred handling command", e);
        }
    }

    private String getDbConnectionString() {
        Properties prop = new Properties();
        try {
            FileInputStream input = new FileInputStream("/opt/zimbra/lib/ext/Announcements/db.properties");
            prop.load(input);

            return prop.getProperty("db_connect_string");
        } catch (IOException ex) {
            ex.printStackTrace();
            return "";
        }
    }


    private Element getAnnouncements(String db_connect_string, Element response) {
        try {
            String result = "";
            //DriverManager.setLogWriter(new PrintWriter(System.out));
            Connection connection = DriverManager.getConnection(db_connect_string);
            PreparedStatement queryApp = null;
            ResultSet announcements = null;
            if (!connection.isClosed())
            {
                queryApp = connection.prepareStatement("SELECT * FROM AnnouncementsEntry order by createDate DESC LIMIT 0, 25");
                announcements = queryApp.executeQuery();

                while (announcements.next()) {
                    Element content = response.addNonUniqueElement("content");
                    content.setText(announcements.getTimestamp("createDate") + "barryseparator" + announcements.getString("userName") + "barryseparator" + announcements.getString("content") + "barryseparator" + announcements.getString("title"));
                }
                announcements.close();
                connection.close();
            }
            return response;
        } catch (Exception ex) {
            Element content = response.addNonUniqueElement("content");
            content.setText("Exception thrown: " + ex.toString());
            return response;
        }
    }
}

