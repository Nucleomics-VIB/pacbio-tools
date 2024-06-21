-------------------------------------------------------------------------
README.txt
-------------------------------------------------------------------------

Data provided by the VIB Nucleomics core (nucleomics@vib.be).

DOWNLOAD USING CURL COMMAND LINE

The shared link would be like this https://nextnuc.gbiomed.kuleuven.be/index.php/s/XZYXZYXZY
where you could identify the token (e.g. XZYXZYXZY), and you should have received a password (e.g. we call it here l_connect_pwd).

        token=XZYXZYXZY
        l_connect_pwd=XXXX

You need also to specify which file you want to download. Usually the data are in archive format (e.g. archive.tgz).
        FILENAME="archive.tgz"

curl -C - -u "${token}:${l_connect_pwd}"  -o "${FILENAME}" "https://nextnuc.gbiomed.kuleuven.be/public.php/webdav/${FILENAME}"

DOWNLOAD USING WRAPPER SCRIPT

You can use the tool developed by Gert Huselmans (Stein Aerts Lab).
The tool only requires the link and password.
Then it lists the content of the share and allows you to select which files you want to download.
https://github.com/aertslab/nextcloud_share_url_downloader

CHECK TRANSFER

If you want to check whether you downloaded the large .tar file correctly, you can use the MD5-checksum (see file ending with md5sum.txt).
The checksum can be obtained with software such as http://winmd5.com.

UNPACK TAR ARCHIVE

To extract the tar archive file on a Linux/MacOSX system, you can use use the command 'tar -xzvf file.tar'
To extract the tar archive file on a Windows system, you can use 7zip (www.7-zip.org/).

------
Keep in mind that we will store your data on our servers only up to three months (starting from the delivery date).
If you have any questions, please contact us.

The VIB Nucleomics BioIT team.

