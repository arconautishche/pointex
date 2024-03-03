defmodule PointexWeb.WatchParty.Voting do
  use PointexWeb, :live_view
  alias Pointex.Model.PossiblePoints
  alias Pointex.Model.ReadModels.WatchPartyVoting
  alias Pointex.Model.Commands
  alias PointexWeb.Endpoint
  alias PointexWeb.WatchParty.Nav
  alias PointexWeb.WatchParty.SongComponents

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Nav.layout wp_id={@wp_id} active={:voting}>
      <div class="flex flex-col sm:flex-row gap-4 my-2">
        <div class="w-full flex flex-col items-center">
          <.button
            :if={@can_submit}
            phx-click="submit_vote"
            class="flex w-fit gap-2 mt-2 bg-gradient-to-br from-red-200 to-red-300 border border-red-400 shadow-lg text-red-800 uppercase hover:from-red-300 hover:to-red-300 active:from-red-200 active:to-red-200"
          >
            <span>🚨</span>
            <span>This is my final decision</span>
            <span>🚀</span>
          </.button>
          <.top_10 songs={@songs} readonly={@vote_submitted} />
        </div>
        <div :if={!@vote_submitted} class="flex flex-col gap-4 w-full overflow-x-hidden">
          <.unvoted_section
            label="👍 Shortlisted"
            songs={unvoted_subset(@songs, :shortlisted)}
            selected_id={@selected_id}
            header_class="bg-gradient-to-r from-green-100"
            used_points={@used_points}
            unused_points={@unused_points}
          />
          <.unvoted_section
            label="🫤 Undecided"
            songs={unvoted_subset(@songs, :meh)}
            selected_id={@selected_id}
            header_class="bg-gradient-to-r from-gray-200"
            used_points={@used_points}
            unused_points={@unused_points}
          />
          <.unvoted_section
            label="💩 Noped"
            songs={unvoted_subset(@songs, :noped)}
            selected_id={@selected_id}
            header_class="bg-gradient-to-r from-red-100"
            used_points={@used_points}
            unused_points={@unused_points}
          />
        </div>
      </div>
    </Nav.layout>
    """
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => wp_id}, _uri, socket) do
    user_id = user(socket).id
    if connected?(socket), do: Endpoint.subscribe("watch_party_voting:#{wp_id}:#{user_id}")

    {:noreply,
     socket
     |> assign(page_title: "Voting")
     |> assign(load_data(wp_id, user_id))
     |> assign(selected_id: nil)}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_selected", params, socket) do
    current_selected_id = socket.assigns.selected_id
    selected_id = if params["id"] == current_selected_id, do: nil, else: params["id"]

    {:noreply, assign(socket, selected_id: selected_id)}
  end

  def handle_event("give_points", params, socket) do
    {song_id, points} =
      case params do
        %{"id" => song_id, "points" => points} -> {song_id, points}
        %{"id" => song_id} -> {song_id, nil}
      end

    :ok =
      Commands.GivePointsToSong.dispatch_new(%{
        watch_party_id: socket.assigns.wp_id,
        participant_id: user(socket).id,
        song_id: song_id,
        points: points
      })

    {:noreply, assign(socket, selected_id: nil)}
  end

  def handle_event("submit_vote", _params, socket) do
    %{wp_id: wp_id} = socket.assigns

    :ok =
      Commands.FinalizeParticipantsVote.dispatch_new(%{
        watch_party_id: wp_id,
        participant_id: user(socket).id
      })

    {:noreply, push_navigate(socket, to: ~p"/wp/#{wp_id}/results")}
  end

  @impl Phoenix.LiveView
  def handle_info(%{event: "updated"}, socket) do
    {:noreply, assign(socket, load_data(socket.assigns.wp_id, user(socket).id))}
  end

  defp load_data(wp_id, user_id) do
    read_model = WatchPartyVoting.get(wp_id, user_id) || %{songs: []}

    used_points =
      read_model.songs
      |> Enum.map(& &1.points)
      |> Enum.reject(&(&1 == 0))
      |> Enum.sort(:desc)

    unused_points = Enum.reject(PossiblePoints.desc(), fn p -> p in used_points end)

    %{
      wp_id: wp_id,
      vote_submitted: read_model.vote_submitted,
      can_submit: unused_points == [] && !read_model.vote_submitted,
      songs: read_model.songs,
      used_points: used_points,
      unused_points: unused_points
    }
  end

  defp unvoted_subset(songs, viewing_result) do
    Enum.filter(songs, &(&1.points < 1 && &1.viewing_result == viewing_result))
  end

  defp voted(songs, points) do
    Enum.find(songs, &(&1.points == points))
  end

  defp top_10(assigns) do
    ~H"""
    <section class="w-full">
      <.section_header label="🏅 My TOP 10" class="" />
      <div class="grid grid-cols-[48px_auto] divide-y divide-gray-200 bg-white shadow-lg border border-gray-200">
        <.points_given
          :for={points <- PossiblePoints.desc()}
          points={points}
          readonly={@readonly}
          song={voted(@songs, points)}
          song_above={voted(@songs, PossiblePoints.inc(points))}
          song_below={voted(@songs, PossiblePoints.dec(points))}
        />
      </div>
    </section>
    """
  end

  defp unvoted_section(assigns) do
    ~H"""
    <section class="w-full">
      <.section_header label={@label} class={@header_class} />
      <div class="flex flex-col divide-y divide-gray-300">
        <.song_with_no_points
          :for={song <- @songs}
          song={song}
          selected={song.id == @selected_id}
          used_points={@used_points}
          unused_points={@unused_points}
        />
      </div>
    </section>
    """
  end

  defp section_header(assigns) do
    ~H"""
    <h2 class={["uppercase text-sm text-gray-500 px-2 py-2", @class]}>
      <%= @label %>
    </h2>
    """
  end

  defp points_given(assigns) do
    %{song: song, song_below: song_below, points: points} = assigns

    assigns =
      assign(
        assigns,
        down_button_params:
          song &&
            if(song_below,
              do: %{"phx-value-id" => song_below.id, "phx-value-points" => points},
              else: %{
                "phx-value-id" => assigns.song.id,
                "phx-value-points" => PossiblePoints.dec(points)
              }
            )
      )

    ~H"""
    <.points_label points={@points} active={@song != nil} />
    <SongComponents.song_container :if={@song} song={@song}>
      <div class="h-full flex gap-4 px-2 py-2 transition-all">
        <SongComponents.description song={@song} />

        <div :if={!@readonly} class="flex gap-1 sm:gap-4 items-center">
          <button
            phx-click="give_points"
            phx-value-id={@song.id}
            phx-value-points={PossiblePoints.inc(@points)}
            class={"#{if @points == 12, do: "invisible"} border border-transparent rounded-lg text-green-600 bg-white/30 backdrop-blur-sm shadow-lg py-2 px-3 hover:bg-transparent sm:hover:bg-green-200 sm:hover:border-green-500 sm:hover:text-green-600 active:text-green-600"}
          >
            <.icon name="hero-arrow-small-up" class="w-8 h-8" />
          </button>
          <button
            phx-click="give_points"
            {@down_button_params}
            class="border border-transparent text-red-600 bg-white/30 backdrop-blur-sm shadow-lg rounded-lg py-2 px-3 hover:bg-transparent sm:hover:bg-red-200 sm:hover:border-red-700 sm:hover:text-red-600 active:text-red-600"
          >
            <.icon name="hero-arrow-small-down" class="w-8 h-8" />
          </button>
        </div>
      </div>
    </SongComponents.song_container>
    <div :if={!@song} class="text-gray-300 px-2 py-2 w-72 transition-all">No song here (yet)</div>
    """
  end

  defp points_label(assigns) do
    ~H"""
    <div class={[
      if(@active, do: "bg-sky-600 text-sky-100", else: "bg-gray-400 text-gray-100 animate-pulse"),
      "font-bold text-2xl flex items-center justify-center transition-all"
    ]}>
      <%= @points %>
    </div>
    """
  end

  defp song_with_no_points(assigns) do
    ~H"""
    <div class={[if(@selected, do: "bg-white shadow", else: "")]}>
      <div
        phx-click="toggle_selected"
        phx-value-id={@song.id}
        class={["flex items-top justify-between gap-2 hover:bg-sky-100"]}
      >
        <SongComponents.song_container song={@song}>
          <div class="flex px-2 sm:px-4 py-3">
            <SongComponents.ro song={@song} />
            <SongComponents.description song={@song} />
          </div>
        </SongComponents.song_container>
      </div>
      <div
        :if={@selected}
        phx-mounted={
          JS.transition(
            {"ease-out duration-200", "scale-y-0 py-0 opacity-50", "scale-y-100 py-4 opacity-100"},
            time: 10
          )
        }
        class="flex flex-col overflow-x-auto bg-gradient-to-b from-gray-200 to-gray-100/50 shadow-inner text-2xl border-t border-gray-200 px-2 origin-top transition-all scale-y-0 py-0 opacity-50"
      >
        <div class="flex">
          <.points_button
            :for={points <- @unused_points}
            points={points}
            song_id={@song.id}
            used={false}
          />
        </div>
        <span :if={@used_points != []} class="mt-3 mb-1 mx-2 text-gray-400 text-xs">
          Already used
        </span>
        <div class="flex">
          <.points_button
            :for={points <- @used_points}
            points={points}
            song_id={@song.id}
            used={true}
          />
        </div>
      </div>
    </div>
    """
  end

  defp points_button(assigns) do
    ~H"""
    <div
      class="px-2 bg-transparent cursor-pointer"
      phx-click="give_points"
      phx-value-id={@song_id}
      phx-value-points={@points}
    >
      <div class={"flex justify-center rounded-full #{if @used, do: "bg-sky-100 border border-sky-600 py-2 text-sky-800", else: "bg-sky-600 py-3 text-white/80"}"}>
        <span class={"text-center #{if @used, do: "w-12 text-xl", else: "w-14"}"}>
          <%= @points %>
        </span>
      </div>
    </div>
    """
  end
end
