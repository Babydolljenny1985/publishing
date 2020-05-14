//= require "trix"
(function() {
  $(document).on('trix-before-initialize', () => {
    Trix.config.blockAttributes.heading1.tagName = 'h2';
    Trix.config.attachments.preview.caption = { name: false, size: false }
  });

  function listenForEditorChange() {
    var $editorContents = $('.js-contents')
      , originalContents = $editorContents.val()
      ;

    document.addEventListener('trix-change', (e) => {
      if ($editorContents.val() != originalContents) {
        $('.js-save').attr('disabled', false);
        $('.js-post-save-button').attr('disabled', true);
      } else {
        $('.js-save').attr('disabled', true);
        $('.js-post-save-button').attr('disabled', false);
      }
    });
  }

  function listenForAttachments() {
    document.addEventListener('trix-attachment-add', (e) => {
      var attachment = e.attachment;

      if (attachment.file) {
        uploadImage(e.attachment.file, setProgress, setAttributes);
      }

      function setProgress(progress) {
        attachment.setUploadProgress(progress); 
      }

      function setAttributes(attributes) {
        attachment.setAttributes(attributes);
      }
    });
  }

  function uploadImage(file, onProgress, onSuccess) {
    var data = new FormData();
    data.append('image', file);

    $.ajax({
      xhr: () => {
        var xhr = new window.XMLHttpRequest();

        // upload progress
        xhr.upload.addEventListener("progress", function(event) {
          var progress = event.loaded / event.total * 100
          onProgress(progress)
        }, false);

        return xhr;
      },
      url: 'upload_image',
      type: 'POST',
      data: data,
      processData: false,
      contentType: false,
      success: onSuccess
    })
  }

  $(function() {
    listenForAttachments();
    listenForEditorChange();
  });
})();
