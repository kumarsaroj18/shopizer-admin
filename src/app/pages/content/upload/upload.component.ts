import { Component, Input } from '@angular/core';

@Component({
  selector: 'upload',
  templateUrl: './upload.component.html',
  styleUrls: ['./upload.component.css']
})
export class UploadComponent {

  files: File[] = [];
  @Input() multi: string

  @Input() onUpload = (files: File[]) => { };

  onFilesChange(event: any) {
    this.files.push(...event.addedFiles);
    this.onUpload([...this.files]);
    this.files.length = 0;
  }

  onRemove(file: File) {
    this.files.splice(this.files.indexOf(file), 1);
  }

}
