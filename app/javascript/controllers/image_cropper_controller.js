import { Controller } from '@hotwired/stimulus';
import Cropper from 'cropperjs';
import Sweetalert2 from 'sweetalert2';
import Translations from '../components/translations';

const SELECTION_ID = 'image-cropper-selection';

// Square selection covering 80% of the image, which can be moved, resized or
// redrawn within the cropper area; the image can be zoomed and moved. Mirrors
// the cropperjs 1 setup (aspectRatio 1, autoCropArea 0.8, viewMode 0).
const TEMPLATE = `
  <cropper-canvas background>
    <cropper-image initial-fit="contain" scalable translatable></cropper-image>
    <cropper-shade hidden></cropper-shade>
    <cropper-handle action="select" plain></cropper-handle>
    <cropper-selection id="${SELECTION_ID}" aspect-ratio="1" initial-coverage="0.8" min-inset="0" movable resizable>
      <cropper-grid role="grid" bordered covered></cropper-grid>
      <cropper-crosshair centered></cropper-crosshair>
      <cropper-handle action="move" theme-color="rgba(255, 255, 255, 0.35)"></cropper-handle>
      <cropper-handle action="n-resize"></cropper-handle>
      <cropper-handle action="e-resize"></cropper-handle>
      <cropper-handle action="s-resize"></cropper-handle>
      <cropper-handle action="w-resize"></cropper-handle>
      <cropper-handle action="ne-resize"></cropper-handle>
      <cropper-handle action="nw-resize"></cropper-handle>
      <cropper-handle action="se-resize"></cropper-handle>
      <cropper-handle action="sw-resize"></cropper-handle>
    </cropper-selection>
  </cropper-canvas>`;

export default class extends Controller {
  static targets = ['imageLoader', 'uploadButton', 'container', 'preview', 'fileNameList'];

  connect() {
    this.imageLoaderTarget.addEventListener('change', () => {
      const file = this.imageLoaderTarget.files[0];
      if (!file) return;

      this._loadImage(file);
      this.fileNameListTarget.innerHTML = file.name;
      this.uploadButtonTarget.classList.remove('disabled');
    });

    const initialUrl = this.containerTarget.dataset.initial;

    if (initialUrl) {
      // Load through a blob URL so that the canvas is never tainted, even
      // if the attachment is served from another origin.
      fetch(initialUrl)
        .then(response => response.blob())
        .then(blob => this._loadImage(blob));
    }
  }

  disconnect() {
    this._destroyCropper();
  }

  uploadImage(event) {
    event.preventDefault();

    const selection = this.cropper?.getCropperSelection();
    if (!selection) return false;

    const submitUrl = this.uploadButtonTarget.getAttribute('data-url');
    const csrfToken = document.querySelector('[name=\'csrf-token\']').content;

    // The selection is measured in screen pixels; export it at the image's
    // natural resolution instead (like cropperjs 1's getCroppedCanvas).
    const [scale] = this.cropper.getCropperImage().$getTransform();

    selection.$toCanvas({ width: Math.round(selection.width / scale) }).then((canvas) => {
      canvas.toBlob((blob) => {
        let formData = new FormData();
        formData.append('croppedImage', blob);

        fetch(submitUrl, {
          method: 'PATCH',
          headers: {
            'X-CSRF-Token': csrfToken
          },
          body: formData
        })
          .then((response) => {
            if(response.status === 200) {
              window.Turbo.visit(window.location);
            }
            else {
              Sweetalert2.fire({
                title: Translations._('Avatar|Uploading avatar failed'),
                icon: 'error',
                cancelButtonText: Translations._('ConfirmDialog|Confirm'),
                showConfirmButton: false,
                showCancelButton: true
              });
            }
          });
      });
    });

    return false;
  }

  // Builds a fresh cropper for every image, so that the selection is
  // initialized against the newly loaded image.
  _loadImage(blob) {
    this._destroyCropper();

    this.objectUrl = URL.createObjectURL(blob);
    const image = new Image();
    image.src = this.objectUrl;

    this.cropper = new Cropper(image, { container: this.containerTarget, template: TEMPLATE });

    const viewer = document.createElement('cropper-viewer');
    viewer.setAttribute('selection', `#${SELECTION_ID}`);
    this.previewTarget.replaceChildren(viewer);
  }

  _destroyCropper() {
    this.cropper?.destroy();
    this.cropper = null;
    this.previewTarget.replaceChildren();

    if (this.objectUrl) {
      URL.revokeObjectURL(this.objectUrl);
      this.objectUrl = null;
    }
  }
}
