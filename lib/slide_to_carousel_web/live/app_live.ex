defmodule SlideToCarouselWeb.AppLive do
  use SlideToCarouselWeb, :live_view

  def error_to_string(:too_large), do: "Too large"
  def error_to_string(:not_accepted), do: "You have selected an unacceptable file type"

  def error_to_string(:too_many_files), do: "You have selected too many files"



  def render(assigns) do
    ~H"""



    <div class="hero min-h-screen bg-gray-200">
  <div class="hero-content text-center">
    <div class="max-w-md">
      <h1 class="text-5xl font-bold mb-8"> Slide to Carousel</h1>

       <div class="card flex-shrink-0 w-full max-w-sm shadow-2xl bg-base-100">
      <div class="card-body">

      <%= cond do %>
      <%= @converting -> %>
    <div class="flex justify-center text-center">
    <button class="bg-indigo-500 text-white p-2 rounded-md" disabled>
      <div class="animate-spin radial-progress bg-indigo-500 text-primary-content border-1 border-gray-200" style="--value:40; --size:2rem"></div>
    Converting... might take a minute
    </button>
    </div>
    <%= length(@uploaded_files) > 0 -> %>
    <div class="flex justify-center text-center">
    <a type="button", href={Enum.at(@uploaded_files,0)} class="bg-indigo-500 text-white p-2 rounded-md" >
    Download
    </a>
    </div>
    <%= true -> %>

        <div class="form-control">

    <%= if @uploaded_files == [] do %>
      <section phx-drop-target={@uploads.slide.ref}>

<%# render each avatar entry %>
<%= for entry <- @uploads.slide.entries do %>
  <article class="upload-entry">

    <figure>
      <figcaption><%= entry.client_name %></figcaption>
    </figure>

    <%# entry.progress will update automatically for in-flight entries %>
    <progress value={entry.progress} max="100"> <%= entry.progress %>% </progress>

    <%# a regular click event whose handler will invoke Phoenix.LiveView.cancel_upload/3 %>
    <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} aria-label="cancel">&times;</button>

    <%# Phoenix.Component.upload_errors/2 returns a list of error atoms %>
    <%= for err <- upload_errors(@uploads.slide, entry) do %>
      <p class="alert alert-danger"><%= error_to_string(err) %></p>
    <% end %>

  </article>
<% end %>

<%# Phoenix.Component.upload_errors/1 returns a list of error atoms %>
<%= for err <- upload_errors(@uploads.slide) do %>
  <p class="alert alert-danger"><%= error_to_string(err) %></p>
<% end %>

</section>

          <form id="upload-form" phx-submit="save" phx-change="validate" >

       <div class="form-control">
          <label class="label">
            <span class="label-text"></span>
          </label>
          <.live_file_input upload={@uploads.slide} />
        </div>

       <div class="form-control">
          <label class="label">
            <span class="label-text">Background color hex code without # (Add file, then hex code)</span>
          </label>
          <input type="text" name="background_color_hex" placeholder="ffffff" class="input input-bordered" />
        </div>


        <div class="form-control mt-6">
          <%= submit "Convert", type: "submit", class: "btn btn-primary", phx_disable_with: "Converting, might take several minutes"%>
        </div>


    </form>

    <% end %>

<%= for entry <- @uploaded_files do %>
    <article class="upload-entry">
    <a class="btn btn-primary" href={entry}> Download </a>

    <%# entry.progress will update automatically for in-flight entries %>

    <%# a regular click event whose handler will invoke Phoenix.LiveView.cancel_upload/3 %>

    <%# Phoenix.Component.upload_errors/2 returns a list of error atoms %>

    </article>
    <% end %>


      </div>
    <% end %>
    </div>
    </div>
    </div>
  </div>
</div>
    """
  end

  def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:uploaded_files, [])
   |> assign(:converting, false)
   |> allow_upload(:slide, accept: ~w(.pdf), max_entries: 1)}
end

def handle_event("validate", params, socket) do
    IO.inspect params
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
  {:noreply, cancel_upload(socket, :slide, ref)}
end

  #File.mkdir_p(path <> "/split")
  #System.cmd("convert",  -resize 1080x1080 -background '#ff2233' -gravity center -extent 1080x1080 split/page
  #-%0d.jpg
  @impl Phoenix.LiveView
  def handle_event("save", params, socket) do
    IO.inspect params
    pid = self()

    spawn(fn ->
    uploaded_files = consume_uploaded_entries(socket, :slide, fn %{path: path}, _entry -> 
    
        #dest = Path.join(["priv", "static", "uploads", Path.basename(path)])
        dest = Path.join([:code.priv_dir(:slide_to_carousel), "static", "uploads", Path.basename(path)])

        input_filename = "input.pdf"
        file_absolute_path = dest <> "/" <> input_filename
        File.mkdir_p(dest <> "/split")
        File.cp!(path, file_absolute_path)
        IO.puts "starting conversion"
        System.cmd("convert", [file_absolute_path, "-resize" ,"1080x1080", "-density", "400", -background" ,"#" <> params["background_color_hex"], "-gravity" ,"center", "-extent", "1080x1080" ,dest <>"/split/page-0%d.pdf"])
        IO.puts "done spliting"
        System.cmd("convert", ["-density" ,"400", dest <> "/split/*.pdf" ,dest <> "/output.pdf"])
        IO.puts "done converting"
        {:ok, Routes.static_path(socket, "/uploads/#{Path.basename(dest) <> "/output.pdf"}")}
      end)
    IO.puts " sending message"
    send(pid, {"done", uploaded_files})
end)
    {:noreply, assign(socket, :converting, true)}
  end

  def handle_info({"done", uploaded_files}, socket) do
    IO.puts "got message"
    new_socket = assign(socket, :converting, false)
    {:noreply, update(new_socket, :uploaded_files, &(&1 ++ uploaded_files))}
  end


end

