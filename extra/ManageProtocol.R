
# gdrive_path <- "LEGEND_grant_proposal_documents"
#
# # Upload Rmd to GDocs
# rmdrive::upload_rmd(file = "Documents/Protocol",
#                     gfile = "LEGEND-T2DM_Protocol",
#                     path = gdrive_path)
#
# rmdrive::update_rmd(file = "Documents/Protocol",
#                     gfile = "LEGEND-T2DM_Protocol",
#                     path = gdrive_path)
#
# # Upload PDF to GDrive (note: will overwrite current document)
# path <- googledrive::drive_get(path = gdrive_path)
# googledrive::drive_upload(media = "Documents/Protocol.pdf",
#                           path = path,
#                           name = "rendered_LEGEND-T2DM_Protocol_rendered.pdf",
#                           overwrite = TRUE)
